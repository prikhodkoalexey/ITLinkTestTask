# Архитектура ITLinkTestTask

## Слои приложения

- **Networking.** `DefaultHTTPClient` выполняет HTTP‑запросы. `DefaultLinksFileRemoteDataSource.fetchLinks()` скачивает `images.txt` и превращает каждую строку в `ImageLinkRecord`. `DefaultImageMetadataProbe.metadata(for:)` при необходимости считывает MIME и подписи файлов. `DefaultRemoteGalleryService` управляет этими компонентами, повторяет неудачные попытки и слушает `DefaultReachabilityService`. На выходе слой отдаёт `LinksFileSnapshot` и метаданные изображений.
- **Storage.** `DefaultDiskStore` создаёт каталоги `Storage/links`, `Storage/thumbnails`, `Storage/originals`. `DefaultLinksFileCache` сериализует `LinksFileSnapshot` в `links.json`. `DefaultImageDataCache` сохраняет превью (PNG) и оригиналы на диск, `DefaultMemoryImageCache` держит те же данные в оперативной памяти. Слоям выше возвращаются `Data`, даже если сети нет.
- **Domain.** `DefaultGalleryRepository` принимает `LinksFileSnapshot`, формирует `GallerySnapshot` с `GalleryItem.image` и `GalleryItem.placeholder`, управляет цепочкой «оперативный кэш → диск → сеть» и предоставляет юзкейсы (`Load`, `Refresh`, `FetchImageData`, `FetchMetadata`).
- **Presentation.** `GalleryViewModel` хранит `GalleryViewState` — модель экрана. `GalleryViewController` вместе с `GalleryImageLoader` отображают грид и подгружают превью. `ImageViewerViewModel` и `ImageViewerViewController` отвечают за полноразмерный просмотр, жесты, перелистывание и шаринг.

---

## Как приложение загружает `images.txt` и формирует модель для грида

Задача: получить текстовый файл, собрать из него `GallerySnapshot` (список `GalleryItem`) и обновить `GalleryViewModel`.

1. `SceneDelegate.scene(_:willConnectTo:options:)` создаёт окно. `AppEnvironment.makeDefault()` настраивает все слои и через `GalleryPresentationAssembly.makeRootViewController()` возвращает `UINavigationController` с `GalleryViewController`.
2. `GalleryViewController.bindViewModel()` подписывается на состояние и запускает `GalleryViewModel.loadInitialSnapshot()`.
3. `GalleryViewModel` вызывает `LoadGallerySnapshotUseCase`, который делегирует работу `DefaultGalleryRepository.loadInitialSnapshot()`.
4. Репозиторий сначала обращается к `DefaultLinksFileCache.loadSnapshot()`. Если `links.json` существует, `GallerySnapshot` собирается локально.
5. При отсутствии кэша `DefaultRemoteGalleryService.refreshLinks()` использует `DefaultLinksFileRemoteDataSource.fetchLinks()`: текст скачивается, проверяется `Content-Type`, каждая строка превращается в `ImageLinkRecord` (картинка, ссылка не на картинку, либо посторонний текст).
6. Свежий `LinksFileSnapshot` сохраняется `DefaultLinksFileCache.saveSnapshot()` и передаётся в `DefaultGalleryRepository.makeSnapshot(from:)`, который формирует `GalleryItem.image` и `GalleryItem.placeholder`.
7. `GalleryViewModel` обновляет `GalleryViewState`, а `GalleryViewController.apply(state:)` применяет diffable snapshot — коллекция получает готовую модель.

---

## Как заполняется ячейка превью

1. После применения снапшота `UICollectionView` создаёт `GalleryImageCell` для элементов с картинками и `GalleryPlaceholderCell` для остальных. В методе `GalleryPlaceholderCell.configure` задаётся конкретная подпись («Ссылка не на изображение» или «Некорректная запись»), чтобы объяснить отсутствие превью.
2. Для `GalleryImageCell` метод `GalleryViewController.loadImage(for:at:cell:)` вызывает `GalleryImageLoader.image(for: .thumbnail(targetSize:scale:))`.
3. `GalleryImageLoader` строит ключ и смотрит в собственный `NSCache`. Если записи нет — обращается к `DefaultMemoryImageCache.data(for:variant:)`.
4. При промахе проверяется `DefaultImageDataCache.data(for:variant:)`, который ищет PNG‑превью на диске (`Storage/thumbnails`) и обновляет дату доступа для LRU.
5. Если данных нет и там, `DefaultGalleryRepository.imageData(for: .thumbnail)` действует по цепочке:
   - рекурсивно запрашивает оригинал (`imageData(for: .original)`), который поочерёдно ищет данные в оперативном кэше, на диске (`Storage/originals`) и, при необходимости, скачивает их через `downloadImage`;
   - сохраняет оригинал в оба кэша;
   - `makeThumbnailData` генерирует PNG‑превью, также записывает его на диск и в память.
6. `GalleryImageLoader.decodeImage` на фоновой очереди превращает `Data` в `UIImage`, размещает его в `NSCache` и передаёт в `GalleryImageCell.configure`.
7. Если ни один уровень не вернул данные (изображение ещё не качали, а сети нет), ячейка остаётся с фоновой заглушкой и отображаемой подписью плейсхолдера.

---

## Как устроен экран просмотра оригиналов

1. `collectionView(_:didSelectItemAt:)` извлекает все `GalleryImage.url`, находит индекс выбранного элемента и через `ImageViewerAssembly` создаёт `ImageViewerViewController`.
2. В `viewDidLoad` контроллер настраивает горизонтальную пагинацию, регистрирует `ImageViewerPageCell`, привязывает обратные вызовы и вызывает `ImageViewerViewModel.start()`.
3. `ImageViewerViewModel.loadItem(at:)` проверяет текущее состояние страницы, запоминает предыдущий `UIImage`, запускает `Task` и обращается к `GalleryImageLoader.image(for: .original)`. Благодаря общей инфраструктуре используются те же кэши.
4. После завершения загрузки статус страницы обновляется: `.loaded(image)` или `.failed(previousImage)`. `ImageViewerPageCell.configure(with:)` показывает индикатор, изображение или кнопку «Повторить», а `adjustImageLayout()` подгоняет `UIScrollView` под текущий снимок. Жесты двойного касания и pinch настроены при создании ячейки.
5. `ImageViewerViewController` управляет `UIPageControl`, скрывает и показывает элементы интерфейса (`toggleChrome`, затрагивая статус‑бар), обрабатывает `handleBack()` и `handleShare()` (создаёт `UIActivityViewController`). `ImageViewerViewModel.loadSurroundings()` заранее подкачивает соседние изображения для плавного листания.

---

## Как всё ведёт себя без интернета

1. `DefaultGalleryRepository.loadInitialSnapshot()` всегда сначала обращается к `DefaultLinksFileCache`. Если `links.json` лежит на диске, список картинок появляется без сети.
2. При `GalleryViewModel.refreshSnapshot()` репозиторий вызывает `DefaultRemoteGalleryService.performWithRetry`. В случае ошибки сервис проверяет `reachability.currentStatus`, и если связи нет, `waitForRetry` включает `DefaultReachabilityService.startMonitoring()`. Как только `NWPath` переходит в `.satisfied` или `.constrained`, монитор отключается, и попытка повторяется автоматически.
3. `GalleryViewController.apply(state:)` при состоянии «пусто + ошибка» запускает `startReachabilityMonitoring()` и `viewModel.retry()` — после восстановления сети загрузка инициируется без участия пользователя.
4. Превью и оригиналы, которые уже лежат в `DefaultImageDataCache` и `DefaultMemoryImageCache`, выдаются сразу. Если конкретное изображение ещё ни разу не загружалось, `DefaultGalleryRepository.imageData` выбрасывает `GalleryRepositoryError.imageDataUnavailable`: в гриде остаётся фон, а `ImageViewerPageCell` показывает кнопку «Повторить».
