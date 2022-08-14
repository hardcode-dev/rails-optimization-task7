Для выполнения текущего задания выбрал свой внутренний проект.
Задача оказалась достаточно не тривиальной в решении.

Начал работу над оптимизацией с профилирования и определения точек роста
`TEST_RUBY_PROF=1 rspec spec`, `rspec --profile spec` предварительно собрав
DX-метрики времени выполнения `test-suite` в `InfluxDB` и построив график в `Chronograf`.

```
Top 10 slowest examples (25.22 seconds, 22.5% of total time):
  Test page. User is admin. Admin can edit answer.
    7.72 seconds ./spec/acceptance/answers/edit_spec.rb:18
  Show. Admin cannot answer the question twice.
    2.78 seconds ./spec/acceptance/tests/show_spec.rb:132
  Show. Student cannot answer the question twice.
    2.73 seconds ./spec/acceptance/tests/show_spec.rb:132
  Homepage. User is admin. admin can create new division.
    1.92 seconds ./spec/acceptance/pages/home_spec.rb:36
  Homepage. User is admin. admin can not create division with invalid params.
    1.85 seconds ./spec/acceptance/pages/home_spec.rb:48
  Index page of subscriptions. Admin can create a new subscription.
    1.8 seconds ./spec/acceptance/subscriptions/index_spec.rb:215
  Index page of subscriptions. Manage subscription. Admin can edit subscription.
    1.68 seconds ./spec/acceptance/subscriptions/index_spec.rb:269
  Demo. User is student. User can pay subscription for division of paid question.
    1.63 seconds ./spec/acceptance/questions/demo_spec.rb:136
  Homepage. User is admin. admin can edit division.
    1.59 seconds ./spec/acceptance/pages/home_spec.rb:59
  Demo. User is student. User can buy subscription for division of paid question.
    1.51 seconds ./spec/acceptance/questions/demo_spec.rb:99

Top 10 slowest example groups:
  Test page.
    2.16 seconds average (8.66 seconds / 4 examples) ./spec/acceptance/answers/edit_spec.rb:3
  Confirmation of subscription.
    1.1 seconds average (1.1 seconds / 1 example) ./spec/acceptance/subscriptions/confirmation_spec.rb:5
  Demo.
    1.06 seconds average (5.31 seconds / 5 examples) ./spec/acceptance/questions/demo_spec.rb:5
  Show test session information.
    0.93916 seconds average (1.88 seconds / 2 examples) ./spec/acceptance/test_sessions/show_spec.rb:3
  Homepage.
    0.87096 seconds average (7.84 seconds / 9 examples) ./spec/acceptance/pages/home_spec.rb:3
  Index.
    0.85505 seconds average (4.28 seconds / 5 examples) ./spec/acceptance/divisions/index_spec.rb:5
  Show.
    0.85313 seconds average (11.09 seconds / 13 examples) ./spec/acceptance/tests/show_spec.rb:5
  Index.
    0.72607 seconds average (2.9 seconds / 4 examples) ./spec/acceptance/feedbacks/index_spec.rb:5
  Index.
    0.7139 seconds average (3.57 seconds / 5 examples) ./spec/acceptance/questions/index_spec.rb:5
  Page of practices.
    0.70118 seconds average (2.8 seconds / 4 examples) ./spec/acceptance/practices/index_spec.rb:3

Finished in 1 minute 52 seconds (files took 11.99 seconds to load)
```

Увидев список самых медленных тестов, решил определить причину медленного выполнения главного из них в
[speedscope](https://www.speedscope.app/)
`TEST_STACK_PROF=1 TEST_STACK_PROF_FORMAT=json rspec spec/acceptance/answers/edit_spec.rb:18`
Причиной медленного выполнения оказалась выполнение `Selenium Driver` для теста.
Было принято решение убрать выполнение `Selenium Driver` в тестах где он не нужен.

Также принято оптимизировать тесты контроллеров при помощи инструментов `test-prof`:
```bash
rspec spec/controllers
```
```
Bafore usage `let_it_be`
Finished in 22.56 seconds (files took 2.65 seconds to load)

After usage `let_it_be`
Finished in 13.73 seconds (files took 2.65 seconds to load)
```

Делаем контрольные замеры после первых этапов оптимизации `rspec --profile spec`:
```
Top 10 slowest examples (21.65 seconds, 20.6% of total time):
  Show. Student cannot answer the question twice.
    2.8 seconds ./spec/acceptance/tests/show_spec.rb:132
  Show. Admin cannot answer the question twice.
    2.78 seconds ./spec/acceptance/tests/show_spec.rb:132
  Homepage. User is admin. admin can not create division with invalid params.
    2.43 seconds ./spec/acceptance/pages/home_spec.rb:48
  Edit block. Admin can add divisions to block.
    2.4 seconds ./spec/acceptance/blocks/edit_spec.rb:43
  Test page. User is admin. Admin can edit answer.
    2.06 seconds ./spec/acceptance/answers/edit_spec.rb:18
  Homepage. User is admin. admin can edit division.
    2.01 seconds ./spec/acceptance/pages/home_spec.rb:59
  Homepage. User is admin. admin can create new division.
    1.91 seconds ./spec/acceptance/pages/home_spec.rb:36
  Index page of subscriptions. Admin can create a new subscription.
    1.82 seconds ./spec/acceptance/subscriptions/index_spec.rb:215
  Demo. User is student. User can pay subscription for division of paid question.
    1.76 seconds ./spec/acceptance/questions/demo_spec.rb:136
  Index page of subscriptions. Manage subscription. Admin can edit subscription.
    1.68 seconds ./spec/acceptance/subscriptions/index_spec.rb:269

Top 10 slowest example groups:
  Confirmation of subscription.
    1.16 seconds average (1.16 seconds / 1 example) ./spec/acceptance/subscriptions/confirmation_spec.rb:5
  Demo.
    1.15 seconds average (5.76 seconds / 5 examples) ./spec/acceptance/questions/demo_spec.rb:5
  Show test session information.
    0.97688 seconds average (1.95 seconds / 2 examples) ./spec/acceptance/test_sessions/show_spec.rb:3
  Homepage.
    0.97442 seconds average (8.77 seconds / 9 examples) ./spec/acceptance/pages/home_spec.rb:3
  Index.
    0.8722 seconds average (4.36 seconds / 5 examples) ./spec/acceptance/divisions/index_spec.rb:5
  Show.
    0.85894 seconds average (11.17 seconds / 13 examples) ./spec/acceptance/tests/show_spec.rb:5
  Index.
    0.75783 seconds average (3.03 seconds / 4 examples) ./spec/acceptance/feedbacks/index_spec.rb:5
  Index.
    0.74047 seconds average (3.7 seconds / 5 examples) ./spec/acceptance/questions/index_spec.rb:5
  Page of practices.
    0.69162 seconds average (2.77 seconds / 4 examples) ./spec/acceptance/practices/index_spec.rb:3
  Edit block.
    0.6659 seconds average (2.66 seconds / 4 examples) ./spec/acceptance/blocks/edit_spec.rb:3

Finished in 1 minute 44.92 seconds (files took 3.11 seconds to load)
```

Удаление использования `Selenium Driver` для тестирования:
```
Top 10 slowest examples (19.74 seconds, 21.7% of total time):
  Test page. User is admin. Admin can edit answer.
    2.98 seconds ./spec/acceptance/answers/edit_spec.rb:18
  Show. Student cannot answer the question twice.
    2.75 seconds ./spec/acceptance/tests/show_spec.rb:132
  Show. Admin cannot answer the question twice.
    2.71 seconds ./spec/acceptance/tests/show_spec.rb:132
  Edit block. Admin can add divisions to block.
    2.55 seconds ./spec/acceptance/blocks/edit_spec.rb:44
  Index page of subscriptions. Admin can create a new subscription.
    1.87 seconds ./spec/acceptance/subscriptions/index_spec.rb:215
  Index page of subscriptions. Manage subscription. Admin can edit subscription.
    1.69 seconds ./spec/acceptance/subscriptions/index_spec.rb:269
  Page of practices. Admin can edit practice.
    1.34 seconds ./spec/acceptance/practices/index_spec.rb:36
  New category. Admin can not create category with invalid params.
    1.3 seconds ./spec/acceptance/blog/categories/new_spec.rb:25
  New category. Admin can create category with valid params.
    1.28 seconds ./spec/acceptance/blog/categories/new_spec.rb:13
  Edit category. Admin can edit category.
    1.27 seconds ./spec/acceptance/blog/categories/edit_spec.rb:14

Top 10 slowest example groups:
  Confirmation of subscription.
    1.16 seconds average (1.16 seconds / 1 example) ./spec/acceptance/subscriptions/confirmation_spec.rb:5
  Show test session information.
    0.99192 seconds average (1.98 seconds / 2 examples) ./spec/acceptance/test_sessions/show_spec.rb:3
  Index.
    0.85709 seconds average (4.29 seconds / 5 examples) ./spec/acceptance/divisions/index_spec.rb:5
  Test page.
    0.85064 seconds average (3.4 seconds / 4 examples) ./spec/acceptance/answers/edit_spec.rb:3
  Index.
    0.73431 seconds average (3.67 seconds / 5 examples) ./spec/acceptance/questions/index_spec.rb:5
  Index.
    0.71706 seconds average (2.87 seconds / 4 examples) ./spec/acceptance/feedbacks/index_spec.rb:5
  Edit block.
    0.70554 seconds average (2.82 seconds / 4 examples) ./spec/acceptance/blocks/edit_spec.rb:4
  New category.
    0.67246 seconds average (2.69 seconds / 4 examples) ./spec/acceptance/blog/categories/new_spec.rb:5
  Home.
    0.67064 seconds average (4.02 seconds / 6 examples) ./spec/acceptance/feedbacks/home_spec.rb:5
  Page of practices.
    0.66466 seconds average (2.66 seconds / 4 examples) ./spec/acceptance/practices/index_spec.rb:3

Finished in 1 minute 30.82 seconds (files took 8.09 seconds to load)
```

Оптимизируем выполнения `acceptance` тестов при помощи инструментов `test-prof`:
```bash
rspec spec/acceptance/
```

До:
```
Finished in 1 minute 14.66 seconds (files took 3.37 seconds to load)
```

После:
```
Finished in 48.38 seconds (files took 10.07 seconds to load)
```

Делаем контрольные замеры после оптимизации `rspec --profile spec`:
```
Top 10 slowest examples (20.08 seconds, 28.7% of total time):
  Home. User is student. User can successfully send new feedback.
    3.28 seconds ./spec/acceptance/feedbacks/home_spec.rb:28
  Show. Student cannot answer the question twice.
    2.92 seconds ./spec/acceptance/tests/show_spec.rb:132
  Show. Admin cannot answer the question twice.
    2.89 seconds ./spec/acceptance/tests/show_spec.rb:132
  Test page. User is admin. Admin can edit answer.
    2.73 seconds ./spec/acceptance/answers/edit_spec.rb:18
  Index page of subscriptions. Admin can create a new subscription.
    1.93 seconds ./spec/acceptance/subscriptions/index_spec.rb:215
  Index page of subscriptions. Manage subscription. Admin can edit subscription.
    1.82 seconds ./spec/acceptance/subscriptions/index_spec.rb:269
  Confirmation of subscription. Admin can confirm the student's subscription.
    1.22 seconds ./spec/acceptance/subscriptions/confirmation_spec.rb:19
  Index page of subscriptions. Manage subscription. Admin can destroy subscription.
    1.13 seconds ./spec/acceptance/subscriptions/index_spec.rb:313
  Demo. User is student. User cannot see answers of demo question.
    1.12 seconds ./spec/acceptance/questions/demo_spec.rb:76
  TestSession Methods. Result. #time_used is expected to eq "00:00:01"
    1.05 seconds ./spec/models/test_session_spec.rb:208

Top 10 slowest example groups:
  Confirmation of subscription.
    1.25 seconds average (1.25 seconds / 1 example) ./spec/acceptance/subscriptions/confirmation_spec.rb:5
  Home.
    0.9821 seconds average (5.89 seconds / 6 examples) ./spec/acceptance/feedbacks/home_spec.rb:5
  Test page.
    0.75484 seconds average (3.02 seconds / 4 examples) ./spec/acceptance/answers/edit_spec.rb:3
  Show.
    0.59268 seconds average (7.7 seconds / 13 examples) ./spec/acceptance/tests/show_spec.rb:5
  Index page of subscriptions.
    0.56221 seconds average (5.62 seconds / 10 examples) ./spec/acceptance/subscriptions/index_spec.rb:3
  List of test sessions.
    0.4267 seconds average (2.13 seconds / 5 examples) ./spec/acceptance/test_sessions/index_spec.rb:3
  Demo.
    0.38668 seconds average (1.93 seconds / 5 examples) ./spec/acceptance/questions/demo_spec.rb:5
  Upload list tests.
    0.35785 seconds average (1.07 seconds / 3 examples) ./spec/acceptance/list_tests/upload_xlsx_spec.rb:3
  Index page.
    0.31419 seconds average (1.57 seconds / 5 examples) ./spec/acceptance/users/index_spec.rb:3
  Show page.
    0.31096 seconds average (1.24 seconds / 4 examples) ./spec/acceptance/users/show_spec.rb:3

Finished in 1 minute 9.87 seconds (files took 7.3 seconds to load)
```

Оптимизируем выполнения `models` тестов при помощи инструментов `test-prof`.
Делаем контрольные замеры после оптимизации `rspec ./spec/models --profile`:
```
Top 10 slowest example groups:
  TestSession
    0.09958 seconds average (1.89 seconds / 19 examples) ./spec/models/test_session_spec.rb:26
  Test
    0.03535 seconds average (0.70706 seconds / 20 examples) ./spec/models/test_spec.rb:30
  User
    0.03438 seconds average (0.75627 seconds / 22 examples) ./spec/models/user_spec.rb:41
  Ability
    0.02904 seconds average (3.4 seconds / 117 examples) ./spec/models/ability_spec.rb:5
  ListTest
    0.02456 seconds average (0.85975 seconds / 35 examples) ./spec/models/list_test_spec.rb:22
  Practice
    0.02394 seconds average (0.35906 seconds / 15 examples) ./spec/models/practice_spec.rb:21
  Answer
    0.02314 seconds average (0.34707 seconds / 15 examples) ./spec/models/answer_spec.rb:29
  Subscription
    0.02264 seconds average (1.02 seconds / 45 examples) ./spec/models/subscription_spec.rb:41
  Question
    0.01981 seconds average (0.37647 seconds / 19 examples) ./spec/models/question_spec.rb:28
  Block
    0.01968 seconds average (0.55103 seconds / 28 examples) ./spec/models/block_spec.rb:22

Finished in 11.3 seconds (files took 11.9 seconds to load)
423 examples, 0 failures, 8 pending
```


До: `rspec ./spec/models/test_session_spec.rb`
```
Finished in 2.17 seconds (files took 2.2 seconds to load)
```

После: `rspec ./spec/models/test_session_spec.rb`
```
Finished in 1.83 seconds (files took 2.57 seconds to load)
```

Устраняем избыточное создание записей в базе данных `FDOC=1 rspec spec/models`:
```
[TEST PROF INFO] FactoryDoctor enabled (event: "sql.active_record", threshold: 0.01)
[TEST PROF INFO] FactoryDoctor report

Total (potentially) bad examples: 24
Total wasted time: 00:00.744

Answer (./spec/models/answer_spec.rb:29) (11 records created, 00:00.034)
  is expected to be empty (./spec/models/answer_spec.rb:76) – 7 records created, 00:00.019
  is expected to eq false (./spec/models/answer_spec.rb:88) – 4 records created, 00:00.014

Block (./spec/models/block_spec.rb:22) (27 records created, 00:00.088)
  is expected to eq true (./spec/support/shared/models/signatory.rb:54) – 9 records created, 00:00.029
  is expected to eq true (./spec/support/shared/models/signatory.rb:55) – 9 records created, 00:00.029
  is expected to eq true (./spec/support/shared/models/signatory.rb:56) – 9 records created, 00:00.029

Division (./spec/models/division_spec.rb:27) (27 records created, 00:00.108)
  is expected to eq true (./spec/support/shared/models/signatory.rb:54) – 9 records created, 00:00.034
  is expected to eq true (./spec/support/shared/models/signatory.rb:55) – 9 records created, 00:00.034
  is expected to eq true (./spec/support/shared/models/signatory.rb:56) – 9 records created, 00:00.039

Practice (./spec/models/practice_spec.rb:21) (27 records created, 00:00.111)
  is expected to eq true (./spec/support/shared/models/signatory.rb:54) – 9 records created, 00:00.035
  is expected to eq true (./spec/support/shared/models/signatory.rb:55) – 9 records created, 00:00.040
  is expected to eq true (./spec/support/shared/models/signatory.rb:56) – 9 records created, 00:00.035

Question (./spec/models/question_spec.rb:28) (7 records created, 00:00.025)
  should auto increment value of number (./spec/models/question_spec.rb:117) – 7 records created, 00:00.025

Subscription (./spec/models/subscription_spec.rb:41) (51 records created, 00:00.233)
  is expected to define enumerize :period_type in: "months", "years" with "months" as default value predicates: true (./spec/support/shared/models/subscribe.rb:11) – 3 records created, 00:00.010
  is expected to eq false (./spec/models/subscription_spec.rb:281) – 4 records created, 00:00.018
  is expected to eq true (./spec/models/subscription_spec.rb:282) – 4 records created, 00:00.015
  is expected to eq false (./spec/models/subscription_spec.rb:312) – 5 records created, 00:00.022
  is expected to eq true (./spec/models/subscription_spec.rb:313) – 5 records created, 00:00.020
  is expected to eq true (./spec/models/subscription_spec.rb:314) – 5 records created, 00:00.019
  is expected to eq :pending (./spec/models/subscription_spec.rb:346) – 5 records created, 00:00.019
  is expected to eq "division-376" (./spec/models/subscription_spec.rb:356) – 5 records created, 00:00.024
  is expected to eq "block-263" (./spec/models/subscription_spec.rb:357) – 5 records created, 00:00.025
  is expected to eq #<Division id: 378, name: "Division 91", slug: "division-91", available: true, created_at: "2022-08-0...on: "      <h1>Tests to the Division 91.</h1>\n      <p>...", per_test_session: 100, spec_page: nil> (./spec/models/subscription_spec.rb:367) – 5 records created, 00:00.026
  is expected to eq #<Block id: 265, name: "Block 102", created_at: "2022-08-06 22:19:43.613456000 +0300", updated_at: "2022-08-06 22:19:43.613456000 +0300", pass: 66, per_test_session: 40, demo_count: 10> (./spec/models/subscription_spec.rb:368) – 5 records created, 00:00.031

User (./spec/models/user_spec.rb:41) (1 record created, 00:00.143)
  is expected to eq "visitor" (./spec/models/user_spec.rb:248) – 1 record created, 00:00.143
  
Finished in 8.6 seconds (files took 2.52 seconds to load)
```

После оптимизации избыточного создания записей в базе данных `FDOC=1 rspec spec/models`:
```
[TEST PROF INFO] FactoryDoctor enabled (event: "sql.active_record", threshold: 0.01)
[TEST PROF INFO] FactoryDoctor report

Total (potentially) bad examples: 12
Total wasted time: 00:00.177

Block (./spec/models/block_spec.rb:22) (9 records created, 00:00.042)
  is expected to eq true (./spec/support/shared/models/signatory.rb:54) – 3 records created, 00:00.014
  is expected to eq true (./spec/support/shared/models/signatory.rb:55) – 3 records created, 00:00.013
  is expected to eq true (./spec/support/shared/models/signatory.rb:56) – 3 records created, 00:00.015

Division (./spec/models/division_spec.rb:27) (9 records created, 00:00.044)
  is expected to eq true (./spec/support/shared/models/signatory.rb:54) – 3 records created, 00:00.013
  is expected to eq true (./spec/support/shared/models/signatory.rb:55) – 3 records created, 00:00.015
  is expected to eq true (./spec/support/shared/models/signatory.rb:56) – 3 records created, 00:00.014

Practice (./spec/models/practice_spec.rb:22) (9 records created, 00:00.040)
  is expected to eq true (./spec/support/shared/models/signatory.rb:54) – 3 records created, 00:00.014
  is expected to eq true (./spec/support/shared/models/signatory.rb:55) – 3 records created, 00:00.012
  is expected to eq true (./spec/support/shared/models/signatory.rb:56) – 3 records created, 00:00.013

Question (./spec/models/question_spec.rb:28) (4 records created, 00:00.013)
  should auto increment value of number (./spec/models/question_spec.rb:117) – 4 records created, 00:00.013

Subscription (./spec/models/subscription_spec.rb:41) (8 records created, 00:00.036)
  is expected to eq :pending (./spec/models/subscription_spec.rb:350) – 5 records created, 00:00.022

Finished in 8.15 seconds (files took 3.24 seconds to load)
```

Отключаем логирование:
```ruby
require 'test_prof/recipes/logging'

config.logger = Logger.new(nil)
config.log_level = :fatal
```

Делаем контрольные замеры после оптимизации `rspec --profile spec`:
```
Top 10 slowest examples (19.18 seconds, 27.5% of total time):
  Show. Admin cannot answer the question twice.
    2.98 seconds ./spec/acceptance/tests/show_spec.rb:132
  Show. Student cannot answer the question twice.
    2.73 seconds ./spec/acceptance/tests/show_spec.rb:132
  Home. User is student. User can successfully send new feedback.
    2.59 seconds ./spec/acceptance/feedbacks/home_spec.rb:28
  Test page. User is admin. Admin can edit answer.
    2.5 seconds ./spec/acceptance/answers/edit_spec.rb:18
  Index page of subscriptions. Admin can create a new subscription.
    2.08 seconds ./spec/acceptance/subscriptions/index_spec.rb:215
  Index page of subscriptions. Manage subscription. Admin can edit subscription.
    1.64 seconds ./spec/acceptance/subscriptions/index_spec.rb:269
  Confirmation of subscription. Admin can confirm the student's subscription.
    1.5 seconds ./spec/acceptance/subscriptions/confirmation_spec.rb:19
  Index page of subscriptions. Manage subscription. Admin can destroy subscription.
    1.11 seconds ./spec/acceptance/subscriptions/index_spec.rb:313
  Home. User is student. User see errors when sending feedback with invalid attributes.
    1.03 seconds ./spec/acceptance/feedbacks/home_spec.rb:43
  TestSession Methods. Result. #time_used is expected to eq "00:00:01"
    1.01 seconds ./spec/models/test_session_spec.rb:208

Top 10 slowest example groups:
  Confirmation of subscription.
    1.55 seconds average (1.55 seconds / 1 example) ./spec/acceptance/subscriptions/confirmation_spec.rb:5
  Home.
    0.85004 seconds average (5.1 seconds / 6 examples) ./spec/acceptance/feedbacks/home_spec.rb:5
  Test page.
    0.71752 seconds average (2.87 seconds / 4 examples) ./spec/acceptance/answers/edit_spec.rb:3
  Show.
    0.60341 seconds average (7.84 seconds / 13 examples) ./spec/acceptance/tests/show_spec.rb:5
  Index page of subscriptions.
    0.55685 seconds average (5.57 seconds / 10 examples) ./spec/acceptance/subscriptions/index_spec.rb:3
  Demo.
    0.42792 seconds average (2.14 seconds / 5 examples) ./spec/acceptance/questions/demo_spec.rb:5
  List of test sessions.
    0.39354 seconds average (1.97 seconds / 5 examples) ./spec/acceptance/test_sessions/index_spec.rb:3
  Upload list tests.
    0.33114 seconds average (0.99342 seconds / 3 examples) ./spec/acceptance/list_tests/upload_xlsx_spec.rb:3
  Index page.
    0.27136 seconds average (1.36 seconds / 5 examples) ./spec/acceptance/users/index_spec.rb:3
  Show page.
    0.26258 seconds average (1.05 seconds / 4 examples) ./spec/acceptance/users/show_spec.rb:3

Finished in 1 minute 9.71 seconds (files took 3.31 seconds to load)
1654 examples, 0 failures, 16 pending
```

Результаты с использованием `gem 'parallel_tests'`
```
Finished in 28.34 seconds (files took 5.09 seconds to load)
32 examples, 0 failures

1654 examples, 0 failures, 16 pendings

Took 35 seconds
Sending metric to InfluxDB
```

Итог: Выполнение тестов ускорилось на `75%` с `1 minute 52 seconds` до `28.34 seconds`.
