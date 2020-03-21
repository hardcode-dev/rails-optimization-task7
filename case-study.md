Тренироваться решено было на нашем тест сьюте

Последний раз мы занимались производительностью год назад и тогда мы адаптировали паралельность тестов и немного поигрались с тестпрофом. Тогда было полторы минуты на моем маке и 1600 тестов.  Сейчас он вдвое вырос по числу тестов и более чем в 3 раза по времени

3516 examples, 0 failures, 28 pendings
Took 309 seconds (5:09)

Для начала я решил посмотреть а не будет ли эффективнее запускать их не в 8 потоков как делает parallel:spec по умолчанию а в 3. Я выбрал 3 потому что у моего мака 4 ядра + гипертрединг. ОДно ядро оставил для СУБД

Стало сильно хуже (больше 8 минут и вроде это был не конец), решил тут пока не эксперементировать

Уже понимая что это займет много времени я запустил rspec --profile и пошел настраивать InfluxDb

Спустя миллион лет (24 минуты) был получен результат
	Top 10 slowest examples (32.92 seconds, 2.3% of total time) 
Тут смотреть неинтересно так как всего 2 процента времени и мне показалось интереснее пойти в медленные группы но и тут не могу сказать что исправление чего-то даст зачимый прирост на общем уровне

	Top 10 slowest example groups:
	  GridBots::FillUsdProfitColumns
	    3.24 seconds average (6.49 seconds / 2 examples) ./spec/services/grid_bots/fill_usd_profit_columns_spec.rb:3
	  MarketplaceItemPurchasesController
	    2.52 seconds average (10.09 seconds / 4 examples) ./spec/controllers/marketplace_item_purchases_controller_spec.rb:3
	  PBKDF2
	    2.17 seconds average (2.17 seconds / 1 example) ./spec/lib/binance_chain/pbkdf2_spec.rb:5
	  GridBots::ProfitsQuery
	    2.04 seconds average (2.04 seconds / 1 example) ./spec/queries/grid_bots/profits_query_spec.rb:3
	  TrackingCodeStat
	    1.73 seconds average (1.73 seconds / 1 example) ./spec/models/tracking_code_stat_spec.rb:15
	  MarketplaceItems::StatsBuilders::FilteredStats
	    1.69 seconds average (18.61 seconds / 11 examples) ./spec/services/marketplace_items/stats_builders/filtered_stats_spec.rb:3
	  MarketplaceItems::StatsBuilders::TotalStats
	    1.59 seconds average (11.15 seconds / 7 examples) ./spec/services/marketplace_items/stats_builders/total_stats_spec.rb:3
	  SignalFollowingEntryProcessors::TelegramBotSignalProcessor
	    1.33 seconds average (19.99 seconds / 15 examples) ./spec/lib/signal_following_entry_processors/bot_signal_processor_spec.rb:3
	  ApiEntries::V3::SmartTradingApi
	    1.25 seconds average (16.19 seconds / 13 examples) ./spec/api/v3/smart_trading_api_spec.rb:5
	  MarketplaceItems::StatsBuilders::TotalStats
	    1.13 seconds average (4.51 seconds / 4 examples) ./spec/services/marketplace_items/stats_builders/base_builder_spec.rb:4


Пойдем к более глобальным вещам. Я давно хотел выпилить DatabaseCleaner, так как далеко не первый разу уже вижу совет - он вам не нужен.  Вот и погнали - убираем из гемфайла, ставим 
  config.use_transactional_fixtures = true, убираем все упоминания DatabaseCleaner, первая возникшая проблема - у нас есть before_suite в котором создаются некоторые вещи и сразу появился конфликт, добавил 3 строчки для чистки этих вещей в этот же before suite, тесты пошли. но некоторые стали падать

3516 examples, 70 failures, там была пара захардкоженых айдишников из 2017, понятия не имею как этой работало с DatabaseCleaner ну да ладно, в итоге время стало получше.

3516 examples, 0 failures, 28 pendings
Took 266 seconds (4:26)


Поигрался еще с числом воркеров но и 6 и 7 оказались хуже 8ми.

Сделал таск rake rspec:run запускающий тесты в паралель и отсылающй данные в influx


	namespace :rspec do
	  desc "run"
	  task run: :environment do
	    require 'etc'
	    require 'tty'

	    cmd = "rake parallel:spec"
	    puts "Running rspec via `#{cmd}`"
	    command = TTY::Command.new(printer: :quiet, color: true)

	    start = Time.now
	    begin
	      command.run(cmd)
	    rescue TTY::Command::ExitError
	      puts 'TEST FAILED SAFELY'
	    end
	    finish = Time.now

	    puts 'SENDING METRIC TO INFLUXDB'
	    TestMetrics.write(user: Etc.getlogin, run_time_seconds: (finish - start).to_i)
	  end
	end


Перейдем к исследованию проблем, попробуем 
	SAMPLE_TESTS=10 TEST_RUBY_PROF=1 rspec 

	-- Crash Report log information --------------------------------------------
	   See Crash Report log file under the one of following:                    
	     * ~/Library/Logs/DiagnosticReports                                     
	     * /Library/Logs/DiagnosticReports                                      
	   for more details.                                                        
	Don't forget to include the above Crash Report log file in bug reports.     
	You may have encountered a bug in the Ruby interpreter or extension libraries.
	Bug reports are welcome.
	For details: https://www.ruby-lang.org/bugreport.html

Ну класс.... 

Обновил ruby 2.6.1 -> 2.6.3 

Теперь Illegal instruction: 4 кааайф

ruby 2.7.0 тоже не помогло, отложим


Попробуем пойти как в презентации - оптимизируем самый медленный тест


	TEST_STACK_PROF=1 TEST_STACK_PROF_FORMAT=json rspec ./spec/controllers/marketplace_item_purchases_controller_spec.rb:49

	[TEST PROF INFO] StackProf (raw) enabled globally: mode – wall, target – suite
	Run options: include {:locations=>{"./spec/controllers/marketplace_item_purchases_controller_spec.rb"=>[49]}}
	.

	Finished in 16.67 seconds (files took 14.38 seconds to load)
	1 example, 0 failures

	[TEST PROF INFO] StackProf report generated: tmp/test_prof/stack-prof-report-wall-raw-total.dump
	[TEST PROF INFO] StackProf JSON report generated: tmp/test_prof/stack-prof-report-wall-raw-total.json

Тут больше 30% sprockets. Шок какой-то что он вообще тут есть. Оказалось что в jbuilder есть image_url и ему надо посчитать hash фйла чтобы сделать правильную ссылку
	  config.assets.enabled = false
	  config.assets.compile = false
	  config.assets.unknown_asset_fallback = true


Попробуем бестпрактис про bcrypt - у нас скорее всего точно каждый тест создает пользователя 

# rails helper
# speed up password generation for tests
BCrypt::Engine.cost = BCrypt::Engine::MIN_COST

И внезапно тесты прогнались за 1:53

Прежде чем проверять я решил еще логирование отключить так как лог был размером в 8гб 

    config.log_level = :fatal

Took 104 seconds (1:44)

Вот так дела. Для понятия что именно дало такой прирост откатил изменения по sprockets - Took 115 seconds (1:55)
Откатил Bcrypt Took 273 seconds (4:33)

Кароч жест какая-то с этим Bcrypt сколько же у нас там настройки стоят


