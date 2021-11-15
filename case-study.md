### Шаг 1. Сбор DX-метрики

- Развернул Chronograf (репозиторий переехал https://github.com/influxdata/sandbox)
- Добавил и настроил Influxer
- Отправить данные из приложения в influxDB так и не вышло, т.к приложение разворачивается в докере,
  Chronograf - также. Спустя относительно продолжительное время так и не удалось настроить доступ к localhost:8086 из контейнера.
  (Errno::EADDRNOTAVAIL: Failed to open TCP connection to localhost:8086 (Cannot assign requested address - connect(2) for "localhost" port 8086))
- В тестовых целях опробовал отправку данных для DEV.to
- В качестве метрики оптимизации приложения будем использовать время прохождения тестового билда, без отправки в influxDB, к сожалению

### Шаг 2. Первый прогон тестов
