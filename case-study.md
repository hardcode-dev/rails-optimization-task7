# Задание № 7

Решил потренироваться на своем проекте.

### Шаг 1. Общая оптимизация
1. Настройка отправки метрик в `InfluxDB`

Добавил гемы influx.db, tty. Сделал прогон

![рис. 1](chronograf_01.png)

1.1. Время выполнения всего test-suite до оптимизации.

```
Finished in 16 minutes 19 seconds (files took 9.9 seconds to load)
1504 examples, 109 failures, 15 pending
```

1.2. Запустил тесты в параллельном режиме в 3 потока.

```
1504 examples, 110 failures, 15 pendings
Took 577 seconds (9:17)
```

1.3. Отключил database_cleaner и логгирование.

```
1504 examples, 110 failures, 15 pendings
Took 499 seconds (8:09)
```

### Шаг 2. Профилирование.

1. Результат работы `rspec --profile`.
```

Finished in 12 minutes 32 seconds (files took 16.51 seconds to load)
1504 examples, 111 failures, 15 pending
```
2. Результат работы `RD_PROF=1 rspec spec...`.

2.1. До оптимизации.
```
Total time: 00:51.766

Total `let` time: 00:08.211
Total `before(:each)` time: 00:39.460

```


2.2. Using before_all & let_it_be in spec.
```
Total time: 00:01.850

Total `let` time: 00:00.000
Total `before(:each)` time: 00:00.158

```

![рис. 2](chronograf_02.png)

2.3. Время выполнения всего test-suite.
```
1504 examples, 110 failures, 15 pendings
Took 295 seconds (4:55)
```