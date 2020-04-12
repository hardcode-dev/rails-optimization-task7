1.1. Сначала пытался оптимизировать один из рабочих проектов. Но ощутимых результатов на том, что там сейчас написано, удалось добиться лишь распараллеливанием:

```bash
TEST_ENV_NUMBER=1 rake test:run

Took 387 seconds (6:27)

TEST_ENV_NUMBER=2 rake test:run

Took 212 seconds (3:32)

TEST_ENV_NUMBER=3 rake test:run

Took 151 seconds (2:31)

TEST_ENV_NUMBER=4 rake test:run

Took 129 seconds (2:09)
```
1.2. Другие инструменты никаких особо очевидных и хоть сколько-то жирных точек роста не показали. Пытался включить транзакционное тестирование, но при нём валились фича-тесты. Пытался настроить работу `DatabaseCleaner` на них, и использование транзакционного метода на всех остальных тестах, но не получилось. Профилирование билдеров тестовых записей тоже особых результатов не принесло. Решил перейти на `dev.to`.

2.1. Первым делом также распараллелил тесты:

```bash
TEST_ENV_NUMBER=1 rake test:run

Took 481 seconds (8:01)

TEST_ENV_NUMBER=2 rake test:run

Took 302 seconds (5:02)

TEST_ENV_NUMBER=3 rake test:run

Took 248 seconds (4:08)

TEST_ENV_NUMBER=4 rake test:run

Took 268 seconds (4:28)
```
На 4 потоках завалилось больше тестов (при первых трёх вариантах наборы упавших совпадали -- связанные с валидацией записей с будущей датой, которая была явно прописана и на момент моих действий была уже прошедшей, что-то связанное с авторизацией твиттера, чьи ключи я не добавлял и что-то подобное). И по времени тестирование в четырёх потоках происходило дольше. Потому остановился на трёх потоках.
2.2. Закомментировал конфиги `DatabaseCleaner`, включил транзакционное тестирование -- состав упавших тестов не изменился, время выполнения уменьшилось:

```bash
TEST_ENV_NUMBER=3 rake test:run

Took 231 seconds (3:51)
```
2.3. Затем ограничил логирование в тестовом окружении:
```bash
TEST_ENV_NUMBER=3 rake test:run

Took 226 seconds (3:46)
```
2.3. После общих мероприятий решил проверить отдельные тесты:

```bash
rspec --profile

Top 10 slowest examples (59.94 seconds, 13.9% of total time):
  Reading list without tags when large readinglist shows the large reading list
    8.87 seconds ./spec/features/user_views_a_reading_list_spec.rb:20
  Reading list without tags when large readinglist shows the large readinglist after user clicks the show more button
    8.72 seconds ./spec/features/user_views_a_reading_list_spec.rb:25
  User visits a homepage when logged in user when user follows tags shows the followed tags
    5.61 seconds ./spec/features/homepage/user_visits_homepage_spec.rb:58
  User visits a homepage when logged in user when user follows tags shows other tags
    5.55 seconds ./spec/features/homepage/user_visits_homepage_spec.rb:71
  User visits a homepage when logged in user when user follows tags shows followed tags ordered by weight and name
    5.55 seconds ./spec/features/homepage/user_visits_homepage_spec.rb:65
  internal/users when deleting user raises a 'record not found' error after deletion
    5.53 seconds ./spec/controllers/internal_users_controller_spec.rb:68
  User visits a homepage when logged in user offers to follow tags
    5.51 seconds ./spec/features/homepage/user_visits_homepage_spec.rb:42
  User visits a homepage when logged in user shows profile content
    5.47 seconds ./spec/features/homepage/user_visits_homepage_spec.rb:34
  Creating Comment User fill out commen box then click previews and submit
    4.58 seconds ./spec/features/comments/user_fills_out_comment_spec.rb:22
  Editing with an editor user click the edit-post button
    4.55 seconds ./spec/features/articles/user_edits_an_article_spec.rb:18

Top 10 slowest example groups:
  Reading list
    4.76 seconds average (19.06 seconds / 4 examples) ./spec/features/user_views_a_reading_list_spec.rb:3
  internal/users
    4.11 seconds average (28.74 seconds / 7 examples) ./spec/controllers/internal_users_controller_spec.rb:3
  User visits a homepage
    4 seconds average (27.97 seconds / 7 examples) ./spec/features/homepage/user_visits_homepage_spec.rb:3
  Creating Comment
    3.61 seconds average (10.82 seconds / 3 examples) ./spec/features/comments/user_fills_out_comment_spec.rb:3
  Organization setting page(/settings/organization)
    2.71 seconds average (5.42 seconds / 2 examples) ./spec/features/organization/user_updates_org_settings_spec.rb:3
  Editing A Comment
    2.17 seconds average (6.52 seconds / 3 examples) ./spec/features/comments/user_edits_a_comment_spec.rb:3
  Editing with an editor
    1.91 seconds average (5.73 seconds / 3 examples) ./spec/features/articles/user_edits_an_article_spec.rb:3
  Deleting Comment
    1.79 seconds average (1.79 seconds / 1 example) ./spec/features/comments/user_delete_a_comment_spec.rb:3
  Visiting article comments
    1.79 seconds average (10.72 seconds / 6 examples) ./spec/features/comments/user_views_article_comments_spec.rb:3
  PodcastFeed
    1.74 seconds average (3.47 seconds / 2 examples) ./spec/labor/podcast_feed_spec.rb:8
```
В топ-5 -- фича-тесты. Их профилирование и изучение того, что в них происходит, ничего многообещающего не дало. Перешёл к самому "толстому" за ними -- `spec/controllers/internal_users_controller_spec.rb`:
```bash
RD_PROF=1 rspec spec/controllers/internal_users_controller_spec.rb

[TEST PROF INFO] RSpecDissect report

Total time: 00:29.591

Total `let` time: 00:04.255
Total `before(:each)` time: 00:27.385

Top 5 slowest suites (by `let` time):

internal/users (./spec/controllers/internal_users_controller_spec.rb:3) – 00:04.255 of 00:29.591 (7)
 ↳ user – 51
 ↳ user3 – 30
 ↳ user2 – 23

Top 5 slowest suites (by `before(:each)` time):

internal/users (./spec/controllers/internal_users_controller_spec.rb:3) – 00:27.385 of 00:29.591 (7)
```
Изменил блоки `before`, воспользовался `let_it_be`, отключил вызовы сервисов, не влияющих на прохождение тестов:
```bash
RD_PROF=1 rspec spec/controllers/internal_users_controller_spec.rb

Total time: 00:04.200

Total `let` time: 00:00.000
Total `before(:each)` time: 00:02.069

Top 5 slowest suites (by `let` time):

internal/users (./spec/controllers/internal_users_controller_spec.rb:3) – 00:00.000 of 00:04.200 (7)
 ↳ user – 44
 ↳ user3 – 30
 ↳ article – 21

Top 5 slowest suites (by `before(:each)` time):

internal/users (./spec/controllers/internal_users_controller_spec.rb:3) – 00:02.069 of 00:04.200 (7)
```
Время выполнения этой спеки уменьшилось в 7 раз. На этом решил остановиться, но, подозреваю, что пройдя по оставшимся спекам, можно было бы добиться совсем внушительных результатов по общему `test-suite`.
