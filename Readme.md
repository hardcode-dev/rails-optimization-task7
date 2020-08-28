### Case-study оптимизации

Для экспериментов я взял самый медленный спек на своем проекте.

1) Первое что я сделал - прогнал его вместе с `RSpecDissect`:
```
[TEST PROF INFO] RSpecDissect report
Total time: 00:23.176
Total `let` time: 00:20.298
Total `before(:each)` time: 00:22.742

Finished in 23.19 seconds (files took 3.52 seconds to load)
```
Создание основных сущностей я переделал с помощью `let_it_be` + вынес некоторые операции (создания второстепенных сущностей) в before_all:
```
[TEST PROF INFO] RSpecDissect report
Total time: 00:03.392
Total `let` time: 00:01.659
Total `before(:each)` time: 00:03.031

Finished in 4.64 seconds (files took 3.54 seconds to load)
```
Время прогона тестов сократилось в 5 раз.

2) Дальше я решил, что надо избавиться от каскадного создания объектов. Для этого подключил `FactoryProf` и прогнал тесты с переменной `FPROF=flamegraph`
Время прогона тестов сократилось еще в двое:
Finished in 2.23 seconds (files took 3.57 seconds to load)

3) Так же запускал с `FactoryDoctor`, но замена `create` на `build_stubbed` не дает значительного прироста, возмжно на всех тестах это будет заметнее.

### Резюме
Выбрав оттельный спек удалось сократить время прогонов тестов в 10 раз.  
Остальные спеки в целом проходят успешно, но есть и красные с которыми нужно разбираться. Но думаю это не составит труда
