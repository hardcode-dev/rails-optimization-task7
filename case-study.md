# Case-study Оптимизация test-suite

Оптимизируем время выполнения тестов для пет-проекта GuildHall, который представлен в 8 ДЗ

## Предварительная настройка

- установлен docker
- склонирован TICK-docker и запущена influxdb
- проверка что Chronograf запущен

## Feedback-Loop

`feedback_loop` для оптимизации:
- проверить время выполнения тестов
- оптимизировать
- снова проверить)

## Находка 0
- Время выполнения 2737 тестов составляет примерно 2.5 минуты, что само по себе очень быстро
- Не вижу смысла проводить какую-то оптимизацию тестов

## Находка 1
- Но есть смысл проверять тесты в параллели, для этого уже был подключен parallel_tests, но не использовался, но использовал его на других проектах

Результат
- время выполнения тестов при использовании 4 процессоров составило 49 секунд (ускорение в 3 раза)

## Rake задача выглядит сейчас таким образом

namespace :test do
  desc 'Run tests'
  task run: :environment do
    abort 'InfluxDB is not running' unless influx_running?

    command = TTY::Command.new(printer: :quiet, color: true)
    command.run('rake ts:rebuild RAILS_ENV=test')
    start = Time.now
    # command.run('rspec')
    command.run('rake parallel:spec[4]')
    finish = Time.now

    TestDurationMetric.write(run_time_seconds: (finish - start).to_i)
  end

  def influx_running?
    influx_endpoint = 'http://localhost:8086'

    command = TTY::Command.new(printer: :null)
    command.run!("curl #{influx_endpoint}/ping").success?
  end
end
