## Проблема

Проблема: в рабочем проекте медленно проходят тесты:
```
Finished in 5 minutes 25 seconds (files took 20.36 seconds to load)
832 examples, 0 failures, 8 pending
```

## Sidekiq
Прогнал профилировщик:
```
[TEST PROF INFO] EventProf results for sidekiq.inline

Total time: 00:15.767 of 05:27.530 (4.59%)
Total events: 1742
```
Заменил на fake!, зафейлилось много тестов. Решил не стабить sidekiq и вернуть все обратно, ибо это не является самой большой точкой роста.


## DatabaseCleaner
Заметил, что в rails_helper.rb используется DatabaseCleaner:
```
  config.before(:suite) do
    DatabaseCleaner.strategy = :truncation, { except: %w(spatial_ref_sys) }
    DatabaseCleaner.clean
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
```
Закомментировал, получил около 10 фейлящих тестов. Тогда решил вынести флаг для example'ов и вызывать очищение базы явно, где надо:

```
  config.before(:each) do |example|
    if example.metadata[:database_cleaner]
      DatabaseCleaner.strategy = :truncation, { except: %w(spatial_ref_sys) }
      DatabaseCleaner.clean
    end
  end
```
В итоге получил почти двухкратный прирост:

`
Finished in 2 minutes 45.5 seconds (files took 26.86 seconds to load)
`

## let_it_be, before_all
Запустил RspecDissect для построения отчета, который показал, что во многих suite многократно пересоздаются записи
(в основном это модель User). Тогда я заменил let на let_it_be в топ 5 спеках. Не везде тесты заработали с первого раза,
во многих сущностях пришлось указать let_it_be для связанных полей, еще в нескольких - указать параметр `reload:true` 
для перезагрузки записи после мутации из предыдущего теста. В результате:

`
Finished in 2 minutes 28.9 seconds (files took 20.99 seconds to load)
`

Повторный прогон RspecDissect показал, что оставшиеся спеки на время выполнения почти не влияют.

## Оптимизация фабрик
Отчет FactoryProf показал печальную картину:
```
[TEST PROF INFO] Factories usage

 Total: 12418
 Total top-level: 2659
 Total time: 01:39.090 (out of 02:32.893)
 Total uniq factories: 21

   total   top-level     total time      time per call      top-level time               name

    3109          83       20.2705s            0.0065s             0.6245s           interest
    3078           0       13.4150s            0.0044s             0.0000s              token
    1539        1487      128.8310s            0.0837s           124.9127s               user
    1536         272       13.5771s            0.0088s             2.1966s           location
    1458          17        7.6440s            0.0052s             0.0899s      search_params
    
    ...
```

Оказалось, что топ 5 фабрик, которые редко вызываются top-level, связаны с фабрикой User. Тогда я вынес эти связи в trait'ы,
и подключил их только в те примеры, где нужно (связь с Interest оказалась вообще не нужна).
В итоге:

`
Finished in 1 minute 50.2 seconds (files took 20.93 seconds to load)
832 examples, 0 failures, 8 pending
`

## FactoryDoctor
Прогнал отчет FactoryDoctor:
```
[TEST PROF INFO] FactoryDoctor report
Total (potentially) bad examples: 72
Total wasted time: 00:05.538
```
Попробовал заменить в предложенных отчетом тестах create на build, в результате многие тесты стали фейлиться.
В конечном счете решил пока оставить как есть, ибо потенциальный выигрыш здесь все равно небольшой.

## Результат

В ходе оптимизации получилось сократить время прохождения тестов с 5 минут 25 секунд до 1 минуты 50 секунд.
