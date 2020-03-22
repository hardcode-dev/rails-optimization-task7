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


Попробовал снова запустить тестпроф - падает как и раньше 

Обновил всю систему до каталины Abort trap: 6

Каким-то чудом все далось запустить

==================================
  Mode: wall(1000)
  Samples: 398544 (3.07% miss rate)
  GC: 33087 (8.30%)
==================================
     TOTAL    (pct)     SAMPLES    (pct)     FRAME
     93685  (23.5%)       60087  (15.1%)     ActiveRecord::ConnectionAdapters::PostgreSQLAdapter#exec_no_cache
     30409   (7.6%)       30409   (7.6%)     #<Module:0x00007ffb209bd138>.lines_to_ignore
     20873   (5.2%)       20873   (5.2%)     (sweeping)
     21830   (5.5%)       16428   (4.1%)     ActiveRecord::ConnectionAdapters::PostgreSQL::DatabaseStatements#execute
     12033   (3.0%)       12033   (3.0%)     (marking)
     19108   (4.8%)       10772   (2.7%)     ActiveRecord::ConnectionAdapters::PostgreSQLAdapter#exec_cache
     39143   (9.8%)        8734   (2.2%)     #<Module:0x00007ffb209bd138>.custom_line
      5282   (1.3%)        5282   (1.3%)     #<Module:0x00007ffb2005bf68>.input_to_storage
      4929   (1.2%)        4896   (1.2%)     BCrypt::Engine.hash_secret
      4601   (1.2%)        4601   (1.2%)     ActiveRecord::Base.logger
      4394   (1.1%)        4394   (1.1%)     block (3 levels) in class_attribute
      7389   (1.9%)        4283   (1.1%)     RSpec::Mocks::AnyInstance::Recorder#ancestor_is_an_observer?
      3823   (1.0%)        3823   (1.0%)     ActiveSupport::Callbacks::CallTemplate#expand
      3355   (0.8%)        3355   (0.8%)     Concurrent::Collection::NonConcurrentMapBackend#[]
      3091   (0.8%)        3091   (0.8%)     String#xor_impl
      3440   (0.9%)        2976   (0.7%)     ActiveModel::AttributeSet#[]
      2880   (0.7%)        2880   (0.7%)     #<Module:0x00007ffb2005bf68>.storage_to_output
      3496   (0.9%)        2801   (0.7%)     block (2 levels) in class_attribute
      2640   (0.7%)        2640   (0.7%)     #<Module:0x00007ffb1b98f9b8>.pbkdf2_hmac
      2556   (0.6%)        2556   (0.6%)     ActiveModel::Attribute#initialize
      2509   (0.6%)        2509   (0.6%)     Concurrent::Collection::NonConcurrentMapBackend#get_or_default
      2413   (0.6%)        2413   (0.6%)     ActiveRecord::Base.default_timezone
      2408   (0.6%)        2408   (0.6%)     ActiveRecord::Associations#association_instance_get
      1898   (0.5%)        1898   (0.5%)     ActiveModel::AttributeMethods::ClassMethods#define_proxy_call
      1873   (0.5%)        1873   (0.5%)     block (2 levels) in class_attribute
      1823   (0.5%)        1823   (0.5%)     Arel::Collectors::PlainString#<<
      9306   (2.3%)        1816   (0.5%)     Arel::Visitors::Visitor#visit
      1814   (0.5%)        1814   (0.5%)     Makara::Logging::Subscriber#current_wrapper_name
      1790   (0.4%)        1788   (0.4%)     ActiveSupport::PerThreadRegistry#instance
      1743   (0.4%)        1743   (0.4%)     ActiveRecord::ConnectionAdapters::TransactionState#finalized?

   Вижу подозрительный lines_to_ignore как выяснилось это часть гема marginalia который размечает для DBA с какой строки был вызван SQL запрос - потенциально 10 процентов можно сэкономить


  Mode: wall(1000)
  Samples: 288816 (10.69% miss rate)
  GC: 16639 (5.76%)
==================================
     TOTAL    (pct)     SAMPLES    (pct)     FRAME
     73033  (25.3%)       51030  (17.7%)     ActiveRecord::ConnectionAdapters::PostgreSQLAdapter#exec_no_cache
     17680   (6.1%)       13851   (4.8%)     ActiveRecord::ConnectionAdapters::PostgreSQL::DatabaseStatements#execute
     10070   (3.5%)       10070   (3.5%)     (sweeping)
     14487   (5.0%)        9028   (3.1%)     ActiveRecord::ConnectionAdapters::PostgreSQLAdapter#exec_cache
      6470   (2.2%)        6470   (2.2%)     (marking)
      4961   (1.7%)        4935   (1.7%)     BCrypt::Engine.hash_secret
     11668   (4.0%)        4380   (1.5%)     RSpec::Mocks::AnyInstance::Recorder#ancestor_is_an_observer?
      3922   (1.4%)        3922   (1.4%)     block (3 levels) in class_attribute
      3695   (1.3%)        3695   (1.3%)     ActiveRecord::Base.logger
      3323   (1.2%)        3323   (1.2%)     ActiveSupport::Callbacks::CallTemplate#expand
      2889   (1.0%)        2889   (1.0%)     #<Module:0x00007fa03e5b73f0>.storage_to_output
      2661   (0.9%)        2661   (0.9%)     String#xor_impl
      2613   (0.9%)        2613   (0.9%)     #<Module:0x00007fa03b883c80>.pbkdf2_hmac
      2983   (1.0%)        2574   (0.9%)     ActiveModel::AttributeSet#[]
      2527   (0.9%)        2527   (0.9%)     Concurrent::Collection::NonConcurrentMapBackend#[]
      3134   (1.1%)        2405   (0.8%)     block (2 levels) in class_attribute
      2118   (0.7%)        2118   (0.7%)     RSpec::Mocks::ObjectReference.name_of
      2117   (0.7%)        2117   (0.7%)     ActiveRecord::Associations#association_instance_get
      2112   (0.7%)        2112   (0.7%)     ActiveModel::Attribute#initialize
      2085   (0.7%)        2085   (0.7%)     Concurrent::Collection::NonConcurrentMapBackend#get_or_default
      1668   (0.6%)        1668   (0.6%)     ActiveRecord::Base.default_timezone
      1665   (0.6%)        1665   (0.6%)     ActiveModel::AttributeMethods::ClassMethods#define_proxy_call
      1610   (0.6%)        1610   (0.6%)     RSpec::Support::ReentrantMutex#enter
      1583   (0.5%)        1583   (0.5%)     block (2 levels) in class_attribute
      1534   (0.5%)        1534   (0.5%)     ActiveSupport::PerThreadRegistry#instance
      1531   (0.5%)        1501   (0.5%)     Market::BinanceDex#order
      1458   (0.5%)        1458   (0.5%)     Makara::Logging::Subscriber#current_wrapper_name
      1455   (0.5%)        1455   (0.5%)     Arel::Collectors::PlainString#<<
      5016   (1.7%)        1391   (0.5%)     ActiveRecord::AttributeMethods::Read#_read_attribute
      1363   (0.5%)        1363   (0.5%)     ActiveRecord::ConnectionAdapters::TransactionState#finalized?


Ушло много строк, размер дампа уменьшился с 350Mb до 250Mb


### Factory Doctor

Попробуем FDOC=1 rspec 

Total (potentially) bad examples: 285
Total wasted time: 00:12.473

Из 4:35 в один поток это выглядит не стоящим исследования дальнейшего

### заметил что в tmp/storage создется много папок и файлов 
Все они одинакоковые с одной и той же иконкой
Их таких 796 штук видимо с какой-то фабирики в active-storage сохраняется

Сделал trait 
trait :with_image do
      	...
end

В другом месте добавил let_it_be вместо let

  config.active_storage.service = :test 

Пара файлов все равно создается, зачем - загадка

Took 100 seconds (1:40)


### проверим boot time

TEST_STACK_PROF=boot rspec ./spec/lib/white_labels/base_site_spec.rb 

Мне показалось много bootsnap storage_to_output и я пошел смотреть что там и как в документации, в процессе просмотра и сравнения с нашими настройками заметил что у анс в тестах eager_load = true зачем-то
Я даже создал новый реилс апп посмотреть что там и там false 
	 # Do not eager load code on boot. This avoids loading your whole application
	  # just for the purpose of running a single test. If you are using a tool that
	  # preloads Rails for running tests, you may have to set it to true.
	  config.eager_load = false  

Понять почему 3 года назад мы поставили в true я не смог, коммит оч сложный и выглядит как будто случпйно зацепили, человек кто делал тоже не помнит. 

Отключил, часть тестов отлетела, поправил область видимости имен и вуаля
Took 92 seconds (1:32)
	  


