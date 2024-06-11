# Case-study оптимизации

Использовал test-suite `dev.to`

## Подготовка

Исключил утомительные capybara-specs:
Почему-то вот так не работает:
```config.exclude_pattern = "#{::Rails.root}/spec/features/**/*_spec.rb"```
А вот так - работает:
```config.filter_run_excluding type: "feature"```

## Сбор DX-метрики

Подключил influxdb через гем influxer и на базе `DX`-метрики времени выполнения тестов построил график в `Chronograf`.

## Parallel tests

Initial time:

```
Finished in 9 minutes 17 seconds (files took 16.42 seconds to load)
1410 examples, 0 failures, 15 pending
```
Подключил gem parallel tests, упали несколько тестов из-за кривых неймспейсов - починил.
Parallel time:

```
[1] Finished in 3 minutes 22.6 seconds (files took 14.6 seconds to load)
453 examples, 0 failures, 6 pending

[2] Finished in 3 minutes 37.9 seconds (files took 16.5 seconds to load)
400 examples, 0 failures, 7 pending

[3] Finished in 3 minutes 42.9 seconds (files took 15.15 seconds to load)
557 examples, 0 failures, 2 pending

1410 examples, 0 failures, 15 pendings
Took 239 seconds (3:59)

```
Почти 3-кратный прогресс однако

## Profiling

Удаляем honeycomb из тестов

``` Took 168 seconds (2:48) ```

rspec --profile

```
Top 10 slowest examples (84.45 seconds, 13.2% of total time):
  internal/users when deleting user raises a 'record not found' error after deletion
    11.41 seconds ./spec/controllers/internal_users_controller_spec.rb:68
  internal/users when banishing user deletes user content
    9.52 seconds ./spec/controllers/internal_users_controller_spec.rb:111
  ...

Top 10 slowest example groups:
  internal/users
    9.29 seconds average (65.05 seconds / 7 examples) ./spec/controllers/internal_users_controller_spec.rb:3

```

Результаты показательны - фиксим `spec/controllers/internal_users_controller_spec.rb`
Before:
`Finished in 37.48 seconds (files took 11.99 seconds to load)`

Добавляем before_all / let_it_be, убираем Worker:
`Finished in 7.22 seconds (files took 12.51 seconds to load)`

Однако на общем времени это сказалось не сильно:

``` Took 160 seconds (2:40) ```

Вывод - если идти по конкретным кейсам, чтобы прирост должен быть значимым нужно поправить ВСЕ. Или искать какие-то очевидные точки роста

Выпилил database cleaner:
`Took 142 seconds (2:22)`

rspec --profile более жирных точек роста не показывает.
FDOC подтвердил общую проблему: очень много лишних записей в тестовую базу:

```
Reaction (./spec/models/reaction_create_spec.rb:3) (24 records created, 00:01.100)
  enqueues the Users::TouchJob (./spec/models/reaction_create_spec.rb:11) – 6 records created, 00:00.262
  enqueues the Reactions::UpdateReactableJob (./spec/models/reaction_create_spec.rb:17) – 6 records created, 00:00.277
  enqueues the Reactions::BustReactableCacheJob (./spec/models/reaction_create_spec.rb:23) – 6 records created, 00:00.264
  enqueues the Reactions::BustHomepageCacheJob (./spec/models/reaction_create_spec.rb:29) – 6 records created, 00:00.295
```
Посмотрим на event-prof:

```
Top 5 slowest suites (by time):
NotificationsIndex (./spec/requests/notifications_spec.rb:3) – 00:16.882 (169 / 35) of 00:21.779 (77.52%)
Notification (./spec/models/notification_spec.rb:3) – 00:12.820 (122 / 41) of 00:15.642 (81.96%)
Comment (./spec/models/comment_spec.rb:3) – 00:11.845 (109 / 38) of 00:12.900 (91.82%)
Article (./spec/models/article_spec.rb:4) – 00:11.735 (118 / 82) of 00:16.142 (72.7%)
User (./spec/models/user_spec.rb:4) – 00:09.692 (116 / 113) of 00:15.571 (62.24%)

```
Но чтобы выигрыш был значимым менять надо все, отдельные спеки погоды не сделают.

Factories usage:
  total   top-level     total time      time per call      top-level time               name
    1482           0       11.2612s            0.0076s             0.0000s           identity
    1476        1274      144.3688s            0.0978s           124.8704s               user
     492         482       73.4155s            0.1492s            71.7692s            article
     165         159        9.7113s            0.0589s             9.4510s            comment

```
Вот тут более показательно - достаточно обойти все спеки и поставить let_it_be для user (в меньшей степени для article) чтобы получить значимый прирост.
'let_it_be(:user)' в spec/models/article_spec.rb выиграл пару секунд

На этом остановимся. Итог: 149 sec. - прогресс неплохой по сравнению с 9 мин.

P.S. На рабочем проекте использую с осени test-prof, но напишу подробнее об этом в 8 задании.
