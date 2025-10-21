# ITLinkTestTask

Тестовое приложение iOS, которое показывает галерею изображений с возможностями просмотра, шаринга и кэширования. Минимальная поддерживаемая версия iOS — 15.6.

## Структура
- `ITLinkTestTask` — основное приложение.
- `ITLinkTestTaskTests` — модульные тесты.
- `ITLinkTestTaskUITests` — UI-тесты.
- `Scripts/` — сервисные скрипты (SwiftLint, установка hook-ов).

## CI на GitHub Actions
- Workflow `CI` запускается для всех `push` и `pull_request` в ветки `main` и `feature/**`.
- Используется `macos-14`, включена защита от параллельных прогонов (`concurrency`).
- Джобы:
  - **SwiftLint** — выполняет `Scripts/run-swiftlint.sh`, кеширует сборку SwiftLint.
  - **Unit Tests** — матрица симуляторов (`iPhone 15 iOS 17.5`, `iPhone 14 iOS 16.4`), кеширует DerivedData и артефакты SwiftPM, выгружает `.xcresult`.
  - **UI Tests** — отдельный прогон UI-тестов на `iPhone 15 iOS 17.5` с публикацией отчёта.
- Артефакты в `Actions` позволяют скачать результаты тестов и открыть их в Xcode.

## Локальный запуск
- Линтер: `Scripts/run-swiftlint.sh`.
- Тесты: `xcodebuild test -project ITLinkTestTask.xcodeproj -scheme ITLinkTestTask -destination "platform=iOS Simulator,name=iPhone 15,OS=17.5" -only-testing:ITLinkTestTaskTests`.
- UI-тесты: `xcodebuild test ... -only-testing:ITLinkTestTaskUITests`.

## Полезные команды
- Установка git-хуков: `Scripts/install-git-hooks.sh`.
- Очистка DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData`.
