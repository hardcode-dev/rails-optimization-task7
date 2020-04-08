# Case-study оптимизации

## Актуальная проблема

В нашем проекте возникла серьёзная проблема.

Необходимо оптимизировать test-suite проекта.

В проекте была установлена утилита rspec для запуска тестов.

Она успешно работала на юнит тестах с проверкой небольшой логики, но когда стали писаться тесты для файлов которые затрагивали вызовы сторонних апи, и acceptance тестов, тесты стали выполняться очень долго.

Я решил исправить эту проблему, оптимизировав тесты.

## Формирование метрики

Чтобы запечатлеть свой прогресс и в дальнейшем защитить его от деградации, я решил сделать сбор DX-метрики времени выполнения test-suite в InfluxDB и построить график в Chronograf.

Для этого я использовал инструменты: https://github.com/influxdata/TICK-docker + https://github.com/palkan/influxer.

!!!вставить картинку

## Гарантия корректности работы оптимизированной программы

Программа поставлялась с тестом. Выполнение этого теста в фидбек-лупе позволяет не допустить изменения логики программы при оптимизации.

## Feedback-Loop

Для того, чтобы иметь возможность быстро проверять гипотезы я выстроил эффективный `feedback-loop`, который позволил мне получать обратную связь по эффективности сделанных изменений за _время, которое у вас получилось_

Вот как я построил `feedback_loop`:

- Выделил из всех тестов с помощью утилит test-prof, те которые выполнялись дольше всего
- Вносил оптимизации в тесты либо в исходники проекта
- Перезапускаю необходимые тесты чтобы посмотреть ничего ли ни сломалось
- Проверяю с помощью профилировщиков --profile от rspec или test-prof, время выполнения теста (прогрессию)
- Коммичу изменения и беру следующую точку роста для оптимизации

## Вникаем в детали системы, чтобы найти главные точки роста

Для того, чтобы найти "точки роста" для оптимизации я воспользовался:

- gem 'parallel_tests' - паралелизация тестов
- gem "test-prof" - сборка утилит и хелперов для оптимизации тестов
- gem "stackprof" - профайлинг входящий в состав test-prof
- gem "ruby-prof" - профайлинг входящий в состав test-prof
- gem "influxer" - сбор метрик запуска тестов
- gem "coverage" - кодовое покрытие проекта

Вот какие проблемы удалось найти и решить

### Находка №1 (матчеры capybara)

Главную точку роста показал отчет --profile

```
Top 10 slowest examples (238.58 seconds, 50.7% of total time):
  ProductTypes Client When productTypeExtraCostPrice not selected When type drawins skip visualization
    31.63 seconds ./spec/features/product_type_spec.rb:85
  ProductTypes Client When productTypeExtraCostPrice not selected When type is visualization_3d skip drawings
    29.41 seconds ./spec/features/product_type_spec.rb:129
  Request new iteration on final_drawing_step with drawing step final drawing to iteration 3
    23.34 seconds ./spec/models/request_spec.rb:286
  Request new iteration on final_drawing_step with drawing step final drawing to iteration 2
    23.22 seconds ./spec/models/request_spec.rb:279
  Request new iteration on final_drawing_step with drawing step init final drawing step
    22.71 seconds ./spec/models/request_spec.rb:273
  Request new iteration on final_drawing_step without drawing step init final drawing step
    22.28 seconds ./spec/models/request_spec.rb:254
  Request new iteration on final_drawing_step without drawing step final drawing to iteration 3
    22.25 seconds ./spec/models/request_spec.rb:265
  Request new iteration on final_drawing_step without drawing step final drawing to iteration 2
    22.16 seconds ./spec/models/request_spec.rb:259
  ProductTypes Client When productTypeExtraCostPrice not selected Show payed popup after layout step
    20.96 seconds ./spec/features/product_type_spec.rb:174
  Request::Billing billings discount 0-1-2-0 payed
    20.62 seconds ./spec/services/request/billing_spec.rb:212

Top 8 slowest example groups:
  ProductTypes
    21.53 seconds average (107.67 seconds / 5 examples) ./spec/features/product_type_spec.rb:5
  Request
    10.16 seconds average (254.07 seconds / 25 examples) ./spec/models/request_spec.rb:52
  Request::Billing
    7.14 seconds average (85.71 seconds / 12 examples) ./spec/services/request/billing_spec.rb:5
  Drawing::Attachment
    3.15 seconds average (9.44 seconds / 3 examples) ./spec/models/drawing/attachment_spec.rb:5
  Request::RemunerationService
    2.01 seconds average (10.04 seconds / 5 examples) ./spec/services/request/remuneration/remuneration_service_spec.rb:5
  Drawing
    1.08 seconds average (2.16 seconds / 2 examples) ./spec/models/drawing_spec.rb:5
  Measurer::RequestsController
    1.02 seconds average (1.02 seconds / 1 example) ./spec/controllers/measurer/requests_controller_spec.rb:5
  Request::Vacancy
    0.02278 seconds average (0.04556 seconds / 2 examples) ./spec/models/request/vacancy_spec.rb:5

Finished in 7 minutes 51 seconds (files took 13.17 seconds to load)
```

Проблема заключалась в том что в capybara можно использовать более быстрые селекторы, которые дадут прирост в скорости выполнения acceptance тестов

```ruby
expect(page).to have_content
# поменял на
expect(page.has_content?
```

- это дало прирост в скорости выполнения тестов на ~ 10 секунд для acceptance тестов

### Находка №2 (поиск и отключение сторонних запросов)

Главную точку роста показал отчет gem coverage, с помощью него я обнаружил многократные вызовы к библиотекам которые отправляли те или иные данные в сторонние серверы по http, а также лишние вызовы сервисов логирования/хранения истории по изменениям объектов в бд.
Я решил добавить return if Rails.env.test? в те методы которые вызывались но никак не были связанны с тестами.
Это дало некоторое ускорение на метрике в Chronograf: скорость выполнения тестов упала с ~250 секунд до ~80-100

### Находка №3 (Tests pitfalls)

Я посмотрел урок Tests pitfalls и решил сверить свой код на наличие основных ошибок.
Сделал фикс
Sidekiq::Testing.fake!
Это дало +5% к скорости выполнения тестов

### Находка №4 (профайлер EventProf)

- C помощью EventProf я обнаружил лишние вызовы upload в нескольких тестов, это дало прирост на каждый тест примерно в ~1-2 секунды

### Находка №5 (профайлер RSpecDissect)

- С помощью RSpecDissect я построил отчет и выделил главные точки роста

```
[TEST PROF INFO] RSpecDissect report

Total time: 00:49.412

Total `let` time: 00:09.733
Total `before(:each)` time: 00:05.979

Top 5 slowest suites (by `let` time):

Request::RemunerationService (./spec/services/request/remuneration/remuneration_service_spec.rb:5) – 00:03.094 of 00:03.315 (5)
 ↳ multistory_apartment – 10
 ↳ apartment_room_rates_for_visualization_3d – 5
 ↳ apartment_studio_rates – 5
Drawing::Attachment (./spec/models/drawing/attachment_spec.rb:5) – 00:02.544 of 00:02.701 (3)
 ↳ request – 6
 ↳ item1 – 5
 ↳ item2 – 3
Request (./spec/models/request_spec.rb:52) – 00:02.424 of 00:14.572 (25)
 ↳ admin – 28
 ↳ prepare_test – 26
 ↳ request – 5
Request::Billing (./spec/services/request/billing_spec.rb:5) – 00:01.032 of 00:07.301 (12)
 ↳ admin – 24
 ↳ client – 12
 ↳ measurer – 12
ProductTypes (./spec/features/product_type_spec.rb:5) – 00:00.430 of 00:20.271 (5)
 ↳ client – 11
 ↳ admin – 8
 ↳ measurer – 5

Top 5 slowest suites (by `before(:each)` time):

Request::Billing (./spec/services/request/billing_spec.rb:5) – 00:04.909 of 00:07.301 (12)
Request::RemunerationService (./spec/services/request/remuneration/remuneration_service_spec.rb:5) – 00:00.923 of 00:03.315 (5)
Request (./spec/models/request_spec.rb:52) – 00:00.098 of 00:14.572 (25)
Measurer::RequestsController (./spec/controllers/measurer/requests_controller_spec.rb:5) – 00:00.032 of 00:00.401 (1)
ProductTypes (./spec/features/product_type_spec.rb:5) – 00:00.006 of 00:20.271 (5)
```

Выделил самый тяжелый тест
`RD_PROF=1 rspec spec/services/request/billing_spec.rb`
`Finished in 7.74 seconds`
Провел оптимизацию с помощью before_all и упрощения логики в тесте, что дало резльтат:
`Finished in 4.26 seconds`

### Находка №5 (профайлер RSpecDissect)

Выделил самый тяжелый тест
`RD_PROF=1 rspec spec/models/drawing/attachment_spec.rb`
`Finished in 3.29 seconds`
Провел оптимизацию с помощью before_all и упрощения логики в тесте, что дало резльтат:
`Finished in 2.36 seconds`

## Результаты (ускорение программы на ~90.28%)

В результате проделанной оптимизации наконец удалось ускорить время выполнения тестов более чем в 10 раз!
Выполнение всего test-suite до оптимизации занимал:
`Finished in 6 minutes 22 seconds`

После оптимизации:
`Finished in 36.66 seconds`

## Защита от регрессии производительности

- Необходимо как то защититься от регрессии, поэтому оставим здесь @TODO
