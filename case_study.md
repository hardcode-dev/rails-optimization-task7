# Задача Попрактиковаться в оптимизации test-suite и сборе DX метрик

Взял для оптимизации LK/production ветку
Сейчас тесты запускаем следующей командой

  bundle exec rspec --exclude-pattern "spec/features/**/**_spec.rb" --tty

Finished in 11 minutes 16 seconds (files took 26.07 seconds to load)
627 examples, 0 failures, 60 pending


Думаю, самые важные и долгие тесты тут вот здесь bundle exec rspec spec/services/


bundle exec rspec spec/services/support/borrowers/merge_spec.rb

Finished in 1 minute 43.34 seconds (files took 26.6 seconds to load)
38 examples, 0 failures

### Feedback-loop

Для эффективного feedback-loop'a мы развернули chronograph и настроили rake таску, которая будет запускать интересующий нас тест и отправлять в influxDB данные по времени прогона. Но на самом деле, удобней было просто  запускать тесты в консоли и видеть сразу и ошибки, и время выполнения. 

### Инструменты профилирования

Для профилиирования тестов я потестил следующие методы:

1) TAG_PROF=type TAG_PROF_FORMAT=html bundle exec rspec spec/services/support/borrowers/merge_spec.rb
дало вот такой результат
```
  [TEST PROF INFO] TagProf report for type

             type          time   total  %total   %time           avg

      __unknown__     00:58.960      38  100.00  100.00     00:01.551
```

2) SAMPLE=10 bundle exec rspec spec/services/support/borrowers/merge_spec.rb
Это вообще ничего не показало и 38 exampl-ов было запущено, а не 10 (видимо это работает опять на количество файлов, а не example-ов)


3) TEST_RUBY_PROF=1 bundle exec rspec spec/services/support/borrowers/merge_spec.rb
для эффективного feedback-loop'а использовать затруднительно, потому что он один тест запускал в 10 раз дольше. 

Finished in 9 minutes 29 seconds (files took 31.42 seconds to load)

при этом рехультат профилирования он так и не выводит, жду уже минут 10. 

4) RD_PROF=1 bundle exec rspec spec/services/support/borrowers/merge_spec.rb
```
  [TEST PROF INFO] RSpecDissect report

  Total time: 00:46.717
  Total `before(:each)` time: 00:40.679
  Total `let` time: 00:41.923

  Top 5 slowest suites (by `before(:each)` time):

  Support::Borrowers::Merge (./spec/services/support/borrowers/merge_spec.rb:5) – 00:40.679 of 00:46.717 (38)

  Top 5 slowest suites (by `let` time):

  Support::Borrowers::Merge (./spec/services/support/borrowers/merge_spec.rb:5) – 00:41.923 of 00:46.717 (38)
```
Это он опять показал мне не самые медленные exampl'ы, а самые медленные файлы спеков (который всего один)

5) В доках к RSpec нашел такой вот флаг

bundle exec rspec spec/services/support/borrowers/merge_spec.rb --profile

`
  Top 10 slowest examples (21.49 seconds, 45.3% of total time):
  Support::Borrowers::Merge#call when provided borrowers found reassigns old borrower's pdl_contracts
    2.46 seconds ./spec/services/support/borrowers/merge_spec.rb:89
  Support::Borrowers::Merge#call when provided borrowers found when telesales working with merged borrowers last open task from old borrower's is still opened
    2.13 seconds ./spec/services/support/borrowers/merge_spec.rb:112
  Support::Borrowers::Merge#call when provided borrowers found updates waste borrower's deleted_at field
    2.13 seconds ./spec/services/support/borrowers/merge_spec.rb:129
  Support::Borrowers::Merge#call when provided borrowers found when telesales working with merged borrowers reassigns comments from closing tasks to last open task
    2.13 seconds ./spec/services/support/borrowers/merge_spec.rb:121
  Support::Borrowers::Merge#call when provided borrowers found reassigns old borrower's applications
    2.12 seconds ./spec/services/support/borrowers/merge_spec.rb:89
  Support::Borrowers::Merge#call when provided borrowers found updates waste borrower's new_borrower_id with remaining borrower's id
    2.12 seconds ./spec/services/support/borrowers/merge_spec.rb:126
  Support::Borrowers::Merge#call when provided borrowers found when telesales working with merged borrowers deletes open tasks from old borrower's ecxept the last one
    2.1 seconds ./spec/services/support/borrowers/merge_spec.rb:109
  Support::Borrowers::Merge#call when provided borrowers found when telesales working with merged borrowers reassigns attempts from closing tasks to last open task
    2.1 seconds ./spec/services/support/borrowers/merge_spec.rb:115
  Support::Borrowers::Merge#call when provided borrowers found updates remaining borrower's repeat_sale flag
    2.1 seconds ./spec/services/support/borrowers/merge_spec.rb:104
  Support::Borrowers::Merge#call when provided borrowers found when telesales working with merged borrowers reassigns sms from closing tasks to last open task
    2.1 seconds ./spec/services/support/borrowers/merge_spec.rb:118
`

все эти тесты находятся в одном контексте, кроме этого контекста, все остальные скипнем. И попробуем запустить руби проф еще раз.
ему все равно этого много, запустим его на первом, попробуем оптимизировать его.

6) TEST_RUBY_PROF=1 bundle exec rspec spec/services/support/borrowers/merge_spec.rb:89 - там списком each 5 exampl-ов выполняется, и этого оказывается для руби профа слишком много. Попробуем на следующем.
```
  Measure Mode: wall_time
  Thread ID: 70353980438800
  Fiber ID: 0
  Total: 27.227724
  Sort by: self_time

   %self      total      self      wait     child     calls  name
    2.64      0.719     0.719     0.000     0.000     1154   PG::Connection#async_exec
    1.55      0.423     0.423     0.000     0.000   173360   Kernel#hash
    1.51      0.411     0.411     0.000     0.000   184208   Kernel#class
    1.45      9.235     0.395     0.000     8.839   186626  *Class#new
    1.08      0.294     0.294     0.000     0.000    83241   Psych::Nodes::Scalar#initialize
    1.05      0.285     0.285     0.000     0.000    65432   Symbol#to_s

  * indicates recursively called methods
```
На первый взгляд какая то неинформативная ерунда. Попробуем запихнуть туда прямо профайлер. 

7) TEST_STACK_PROF=1 TEST_STACKPROF_FORMAT=json bundle exec rspec spec/services/support/borrowers/merge_spec.rb

bundle exec stackprof --callgrind tmp/test_prof/stack-prof-report-wall-total.dump > tmp/cgd.cgd
qcachegrind tmp/cgd.cgd

судя по отчету, более 15% времени съедают ActiveRecord::ConnectionAdapters. Оценим Factories

8) FPROF=1 bundle exec rspec spec/services/support/borrowers/merge_spec.rb
```
  1728              0         repeat_loan_service_fee
  1728              0      repeat_loan_consulting_fee
   528              0       first_loan_consulting_fee
   528              0          first_loan_service_fee
   276              0                internal_account
   276              0                external_account
   260            244                        borrower
    60              0                    village_unit
    60              0                        province
    60              0                   province_unit
    60              0                        district
    60              0                   district_unit
    60              0                            city
    60              0                         village
    60              0                      occupation
    60              0                       guarantor
    60             44                     application
    60              0                       city_unit
    32             32                         comment
    32              0                           staff
    32             32                            task
    16              0            flff_fee_sub_account
    16              0            rlff_fee_sub_account
    16             16                         account
    16             16                             sms
    16              0                        sms_type
    16             16           repeat_borrowers_risk
    16             16                      block_list
    16             16           pay_day_loan_contract
    16              0     active_pay_day_loan_product
    16              0                contract_account
    16              0               technical_account
    16              0           principal_sub_account
    16              0            interest_sub_account
    16              0    overdue_interest_sub_account
    16              0    disbursement_fee_sub_account
    16              0    late_payment_fee_sub_account
    16              0    prolongation_fee_sub_account
    16              0         service_fee_sub_account
    16              0      consulting_fee_sub_account
```

9) FDOC=1 bundle exec rspec spec/services/support/borrowers/merge_spec.rb
```
  [TEST PROF INFO] FactoryDoctor report

  Total (potentially) bad examples: 1
  Total wasted time: 00:00.170

  Support::Borrowers::Merge (./spec/services/support/borrowers/merge_spec.rb:5)
    returns nil if borrower absent (./spec/services/support/borrowers/merge_spec.rb:152) – 18 records created, 00:00.170
```

10) FPROF=flamegraph bundle exec rspec spec/services/support/borrowers/merge_spec.rb

Судя по отчету, мы создаем на фабриках за время работы теста 6384 объекта.


### Исходные показатели

Итак, время выполнения теста: 70 - 75 секунд. (49.51 seconds (files took 21.13 seconds to load))
За это время создается 6384 объектов.

Постараемся эти показатели сократить.

### Гипотеза 1 parallel_tests

Добавим gem 'parallel_tests'

подключил его, но результат отрицательный. Наверное это потому, что тестирую я его на одной лишь спеке. В общем, то, сам гем этого не скрывает
`1 processes for 1 specs, ~ 1 specs per process`

Так что для конкретно этой цели от этой идеи можно наверное отказаться.

Для всех же спеков результат получается такой:

4 processes for 93 specs, ~ 23 specs per process

Finished in 3 minutes 29.8 seconds (files took 35.64 seconds to load)
133 examples, 0 failures

Finished in 5 minutes 11 seconds (files took 35.7 seconds to load)
173 examples, 0 failures, 34 pending

Finished in 6 minutes 24 seconds (files took 35.73 seconds to load)
167 examples, 0 failures, 18 pending

Finished in 6 minutes 47 seconds (files took 35.71 seconds to load)
154 examples, 0 failures, 8 pending

627 examples, 0 failures, 60 pendings

Took 454 seconds (7:34)


Тогда как в один процесс эта процедура занимает почти в два раза больше времени:

Finished in 12 minutes 1 second (files took 22.41 seconds to load)
627 examples, 0 failures, 60 pending

### Гипотеза 2 let_it_be

С let_it_be пришлось повозиться, но зато прирост "на лицо":

Finished in 14.35 seconds (files took 20.11 seconds to load)
38 examples, 0 failures

Проблема была в том, что появились странные плавающие тесты. У let_it_be напрочь не работают reload: true и refind: true. Попытка добавить конфигурацию из доков вызывает ошибку `undefined method 'configure' for module TestProf::LetItBe`. Вроде бы пофиксить их удалось, но до конца причина мне не ясна. Видимо, он совершенно не умеет обновлять данные из "верхнего уровня" (которые мы задаем в let_it_be).

### Гипотеза 3 попробуем отказаться от синтаксиса типа expect `{ ... }.to change { ... }.from(..).to(..)` 
В последней части теста у меня 13 exampl-ов такого типа, каждый из которых вызывает тестируемый сервис. С помощью before_all, я думаю, можно заменить все эти вызовы на один.

Но эксперимент не увенчался успехом, опять появились неадекватные пассажи, как, например, некоторые переменные, вынесенные в let_it_be, на деле оказываются nil. Причем, раз от разу в разных местах. То ли я неправильно как то пользуюсь этим инструментом, то ли инструмент откровенно сырой.


### Запустим профилировщики после оптимизации

FDOC=1 bundle exec rspec spec/services/support/borrowers/merge_spec.rb
```
  [TEST PROF INFO] FactoryDoctor says: "Looks good to me!"
```
FPROF=1 bundle exec rspec spec/services/support/borrowers/merge_spec.rb

```
[TEST PROF INFO] Factories usage

 total      top-level                            name

   108              0         repeat_loan_service_fee
   108              0      repeat_loan_consulting_fee
    33              0       first_loan_consulting_fee
    33              0          first_loan_service_fee
     9              0                internal_account
     9              0                external_account
     8              7                        borrower
     6              0                    village_unit
     6              0                        province
     6              0                   province_unit
     6              0                        district
     6              0                   district_unit
     6              0                            city
     6              0                         village
     6              0                      occupation
     6              0                       guarantor
     6              5                     application
     6              0                       city_unit
     2              2                         comment
     2              0                           staff
     2              2                            task
     1              0            flff_fee_sub_account
     1              0            rlff_fee_sub_account
     1              1                         account
     1              1                             sms
     1              0                        sms_type
     1              1           repeat_borrowers_risk
     1              1                      block_list
     1              1           pay_day_loan_contract
     1              0     active_pay_day_loan_product
     1              0                contract_account
     1              0               technical_account
     1              0           principal_sub_account
     1              0            interest_sub_account
     1              0    overdue_interest_sub_account
     1              0    disbursement_fee_sub_account
     1              0    late_payment_fee_sub_account
     1              0    prolongation_fee_sub_account
     1              0         service_fee_sub_account
     1              0      consulting_fee_sub_account
```

FPROF=flamegraph bundle exec rspec spec/services/support/borrowers/merge_spec.rb


Судя по отчетам, нагрузка на Factories снижена ровно в 16 раз (создавалось 6384 объекта, теперь 399)! При этом Время выполнения сократилось в два раза (с 70 секунд до менее чем 35 вместе с загрузкой файлов), а если не учитывать загрузку файлов, то более чем в три!
(49.51 seconds (files took 21.13 seconds to load)) -> Finished in 14.35 seconds (files took 20.11 seconds to load).

Учитывая, что параллельное тестирование даст еще двухкратный прирост, нам удалось открыть потенциально четырехкратное ускорение CI, а если заглянуть на фабрики, и почикать их, думаю, эту цифру можно будет и еще увеличить.

