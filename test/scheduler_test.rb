require File.dirname(__FILE__) + '/test_helper'

class Resque::SchedulerTest < Test::Unit::TestCase

  def setup
    Resque::Scheduler.clear_schedule!
  end

  def test_log_location_is_dev_null_on_mute
    ENV['MUTE'] = "1"
    assert_equal "/dev/null", Resque::Scheduler.log_location
  ensure
    ENV.delete('MUTE')
  end

  def test_log_location_is_log_file_if_given
    ENV['LOG_FILE'] = '/tmp/log.txt'
    assert_equal '/tmp/log.txt', Resque::Scheduler.log_location
  ensure
    ENV.delete('LOG_FILE')
  end

  def test_log_location_is_stdout_if_no_overrides_given
    ['MUTE', 'LOG_FILE'].each { |key| ENV.delete(key) }
    assert_equal STDOUT, Resque::Scheduler.log_location
  end

  def test_init_logger_sets_level_info_by_default
    Resque::Scheduler.init_logger
    assert_equal Logger::INFO, Resque::Scheduler.logger.level
  ensure
    mute_logger
  end

  def test_init_logger_sets_level_debug_in_verbose_mode
    ENV['VERBOSE'] = "1"
    Resque::Scheduler.init_logger
    assert_equal Logger::DEBUG, Resque::Scheduler.logger.level
  ensure
    ENV.delete('VERBOSE')
    mute_logger
  end

  def test_enqueue_from_config_puts_stuff_in_the_resque_queue_without_class_loaded
    Resque::Job.stubs(:create).once.returns(true).with('joes_queue', 'BigJoesJob', '/tmp')
    Resque::Scheduler.enqueue_from_config('cron' => "* * * * *", 'class' => 'BigJoesJob', 'args' => "/tmp", 'queue' => 'joes_queue')
  end
  
  def test_enqueue_from_config_puts_stuff_in_the_resque_queue
    Resque::Job.stubs(:create).once.returns(true).with(:ivar, 'SomeIvarJob', '/tmp')
    Resque::Scheduler.enqueue_from_config('cron' => "* * * * *", 'class' => 'SomeIvarJob', 'args' => "/tmp")
  end

  def test_enqueue_from_config_puts_stuff_in_the_resque_queue_when_env_match
    # The job should be loaded : its rails_env config matches the RAILS_ENV variable:
    ENV['RAILS_ENV'] = 'production'
    assert_equal(0, Resque::Scheduler.rufus_scheduler.all_jobs.size)

    Resque.schedule = {:some_ivar_job => {'cron' => "* * * * *", 'class' => 'SomeIvarJob', 'args' => "/tmp", 'rails_env' => 'production'}}
    Resque::Scheduler.load_schedule!
    assert_equal(1, Resque::Scheduler.rufus_scheduler.all_jobs.size)

    # we allow multiple rails_env definition, it should work also:
    Resque.schedule = {:some_ivar_job => {'cron' => "* * * * *", 'class' => 'SomeIvarJob', 'args' => "/tmp", 'rails_env' => 'staging, production'}}
    Resque::Scheduler.load_schedule!
    assert_equal(2, Resque::Scheduler.rufus_scheduler.all_jobs.size)
  end

  def test_enqueue_from_config_dont_puts_stuff_in_the_resque_queue_when_env_doesnt_match
    # RAILS_ENV is not set:
    assert_equal(0, Resque::Scheduler.rufus_scheduler.all_jobs.size)
    Resque.schedule = {:some_ivar_job => {'cron' => "* * * * *", 'class' => 'SomeIvarJob', 'args' => "/tmp", 'rails_env' => 'staging'}}
    Resque::Scheduler.load_schedule!
    assert_equal(0, Resque::Scheduler.rufus_scheduler.all_jobs.size)

    # SET RAILS_ENV to a common value:
    ENV['RAILS_ENV'] = 'production'
    Resque.schedule = {:some_ivar_job => {'cron' => "* * * * *", 'class' => 'SomeIvarJob', 'args' => "/tmp", 'rails_env' => 'staging'}}
    Resque::Scheduler.load_schedule!
    assert_equal(0, Resque::Scheduler.rufus_scheduler.all_jobs.size)
  end

  def test_enqueue_from_config_when_rails_env_arg_is_not_set
    # The job should be loaded, since a missing rails_env means ALL envs.
    ENV['RAILS_ENV'] = 'production'
    assert_equal(0, Resque::Scheduler.rufus_scheduler.all_jobs.size)
    Resque.schedule = {:some_ivar_job => {'cron' => "* * * * *", 'class' => 'SomeIvarJob', 'args' => "/tmp"}}
    Resque::Scheduler.load_schedule!
    assert_equal(1, Resque::Scheduler.rufus_scheduler.all_jobs.size)
  end

  def test_config_makes_it_into_the_rufus_scheduler
    assert_equal(0, Resque::Scheduler.rufus_scheduler.all_jobs.size)

    Resque.schedule = {:some_ivar_job => {'cron' => "* * * * *", 'class' => 'SomeIvarJob', 'args' => "/tmp"}}
    Resque::Scheduler.load_schedule!

    assert_equal(1, Resque::Scheduler.rufus_scheduler.all_jobs.size)
  end

  def test_adheres_to_lint
    assert_nothing_raised do
      Resque::Plugin.lint(Resque::Scheduler)
    end
  end

end
