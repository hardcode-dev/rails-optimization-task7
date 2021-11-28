# Подготовка

Подключил `bootsnap`. 
Попытался отключить от проекта `DatabaseCleaner`, но тесты падают с непонятной ошибкой, 
потому решил пока что его не трогать, чтобы не тратить время.
Практика показывает, что какого-то ощутимого падения производительности test suite'а он не вызывает.

# Профилирование фабрик

`FPROF=1 rspec`

```
[TEST PROF INFO] Factories usage

 Total: 1336
 Total top-level: 744
 Total time: 00:06.663 (out of 00:13.090)
 Total uniq factories: 15

   total   top-level     total time      time per call      top-level time               name

     542          15        1.5699s            0.0029s             0.0478s             office
     527         491        4.3891s            0.0083s             4.0996s               user
      66          59        0.2743s            0.0042s             0.2505s  oauth_application
      34          34        0.1246s            0.0037s             0.1246s users_oauth_application
      29          29        1.4607s            0.0504s             1.4607s       user_account
      29          15        0.0944s            0.0033s             0.0455s               team
      29          21        0.0690s            0.0024s             0.0453s               host
      28          28        0.0709s            0.0025s             0.0709s         vpn_server
      24          24        0.2539s            0.0106s             0.2539s            vpn_key
      12          12        0.1038s            0.0087s             0.1038s            mailbox
      10          10        0.1196s            0.0120s             0.1196s            api_log
       2           2        0.0190s            0.0095s             0.0190s       access_token
       2           2        0.0160s            0.0080s             0.0160s       access_grant
       1           1        0.0035s            0.0035s             0.0035s         users_host
       1           1        0.0024s            0.0024s             0.0024s   users_vpn_server
```

В глаза сразу бросается, что в топе висит `office` - быть на первом месте он точно не должен.
Посмотрев на фабрики, становится ясно, что он каскадно создается при создании записи `user`.

# RSpecDissect

`RD_PROF=1 rspec`

```
TEST PROF INFO] RSpecDissect report

Total time: 00:15.160

Total `let` time: 00:09.162
Total `before(:each)` time: 00:06.904

Top 5 slowest suites (by `let` time):

Api::V2::AccountsController (./spec/controllers/api-v2/accounts_controller_spec.rb:4) – 00:02.078 of 00:02.640 (71)
 ↳ record1 – 92
 ↳ record2 – 72
 ↳ record3 – 72
```

Как видно, в топе находится api-v2 endpoint. Покопаем глубже под него. 

# stackprof flamegraph
`TEST_STACK_PROF=1 TEST_STACK_PROF_FORMAT=json rspec spec/controllers/api-v2/`

Ничего примечательного не нашел, в топе вызовов все стандартно.

# ruby-prof calltree
`TEST_RUBY_PROF=call_tree rspec spec/controllers/api-v2/`

Аналогично, ничего примечательного.

# Factory Flamegraph

`FPROF=flamegraph rspec spec/controllers/api-v2/`

![Screenshot](reports/factory_flame_before.jpg?raw=true)

Вот тут уже становится жарко - присутствует очень большое количество созданных фабрикой записей в БД, с каскадностью.
Нужно исправлять.

При этом, `test-prof` пишет, что все в норме. Но это точно не так и следует исправить.

`[TEST PROF INFO] FactoryDoctor says: "Looks good to me!"`

# Оптимизация api/v2

Воспользуемся `before_all` для того, чтобы не создавать множество одинаковых записей.

![Screenshot](reports/factory_flame_after.jpg?raw=true)

После оптимизации вместо ~350 записей создается лишь 19.
Этот блок тестов пропал из всех отчетов, при этом общее время выполнения уменьшилось на 33% (15 -> 10 секунд),
для `let` и `before(:each)` - примерно на 50%.

```
[TEST PROF INFO] RSpecDissect report

Total time: 00:10.049

Total `let` time: 00:05.372
Total `before(:each)` time: 00:03.610
```

# Параллельные тесты

Подключил `gem 'parallel_test'`

Попробую найти оптимальное количество параллельных процессов.

Для 1: 10.5 (+ 2.5) с.

Для 2: 8 с.

Для 3: 7 с.

Для 4: 6 c.

Выглядит оптимальным использовать 3 процесса, далее прирост получается совсем незначительным.

# Вывод

![Screenshot](reports/influx_graph.jpg?raw=true)

Достаточно быстро получилось ускорить test suite в 2 раза.
Очень хороший результат для кажущегося до этого неплохого test suite'а.
