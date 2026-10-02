# Как получить Vlagomer.ipa

1. Создайте на github.com пустой репозиторий (можно приватный).
2. Загрузите в него всё содержимое этой папки (включая скрытую папку .github).
3. Откройте вкладку Actions -> "Build IPA" -> Run workflow. Через ~3-5 минут
   в разделе Artifacts появится Vlagomer-ipa (внутри Vlagomer.ipa).
4. IPA собран без подписи. Установите на iPhone через Sideloadly или AltStore
   (подпишут вашим бесплатным Apple ID; приложение работает 7 дней, потом переподписать).
   Для постоянной установки нужен платный Apple Developer Program ($99/год) и подпись в Xcode.

Bundle ID: com.example.vlagomer. Смените его в project.yml на свой, если Sideloadly ругнётся.
