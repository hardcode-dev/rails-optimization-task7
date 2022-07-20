## Подготовка

- [x] Локальный запуск репозитория `dev.to`.
- [x] Настройка `TICK stack`.

## Оптимизация

1. При первом прогоне время выполнения тестов составило:
```
Total time: 397 s.
```
2. Я установил значение `:fatal` для `log_level` и запустил тесты в параллельном режиме, время выполнения уменьшилось вдвое:
```
Total time: 181 s.
```
3. Далее я решил поэкспериментировать и увеличил количество потоков до 6: `parallel:spec[6]`, но многие тесты начали сыпаться и покрытие сократилось до 35% — виден провал в начале графика. После того как я устранил проблему, покрытие вновь вернулось к изначальному уровню, но прирост скорости был не таким значительным:
```
Total time: 160 s.
```
Такое значение прохождения полного сьюта меня устраивало, поэтому я решил заняться непосредственно оптимизацией.

4. Я использовал `rspec --profile` для определения наиболее медленных тестов.
```
Top 10 slowest example groups:
  Reading list
    4.48 seconds average (17.9 seconds / 4 examples) ./spec/features/user_views_a_reading_list_spec.rb:3
  internal/users
    3.66 seconds average (25.64 seconds / 7 examples) ./spec/controllers/internal_users_controller_spec.rb:3
  Creating Comment
    3.18 seconds average (9.53 seconds / 3 examples) ./spec/features/comments/user_fills_out_comment_spec.rb:3
...
```
Основным кандидатом на оптимизацию стал тест `internal_users_controller_spec.rb`. Я изучил отчеты `stackprof` и увидел, что большую часть времени занимает вызов `BacktraceCleaner`, после отключения гема `honeycomb` в окружении `test` я получил следующие результаты:
```
Top 10 slowest example groups:
  Creating Comment
    3.06 seconds average (9.17 seconds / 3 examples) ./spec/features/comments/user_fills_out_comment_spec.rb:3
  Reading list
    2.73 seconds average (10.93 seconds / 4 examples) ./spec/features/user_views_a_reading_list_spec.rb:3
  internal/users
    2.48 seconds average (17.39 seconds / 7 examples) ./spec/controllers/internal_users_controller_spec.rb:3
...
```
```
[TEST PROF INFO] RSpecDissect report

Total time: 00:17.107
```
Далее я удалил из спеки вызовы `Delayed::Worker`:
```
[TEST PROF INFO] RSpecDissect report

Total time: 00:04.699
```
И использовал хелперы `let_it_be` и `before_all`:
```
[TEST PROF INFO] RSpecDissect report

Total time: 00:01.073
```

Общее время выполнения тест-сьюта также уменьшилось:
```
Total time: 102 s.
```

## Результаты

В результате проделанной работы мне удалось значительно уменьшить время прохождения тестов — с 397 до 102 секунд.

![Chronograf](chronograf.png)
