template_url = 'https://raw.githubusercontent.com/manuelvanrijn/rails-template/master/templates'

def download_file(url)
  run "curl --progress-bar --location --remote-name #{url}"
end

def say_recipe(name); say "\033[1m\033[36m" + "recipe".rjust(10) + "\033[0m" + "  Running #{name} recipe..." end

def ask_wizard(question)
  ask "\033[1m\033[36m" + ("option").rjust(10) + "\033[1m\033[36m" + "  #{question}\033[0m"
end

def yes_wizard?(question)
  answer = ask_wizard(question + " \033[33m(y/n)\033[0m")
  case answer.downcase
    when "yes", "y"
      true
    when "no", "n"
      false
    else
      yes_wizard?(question)
  end
end

def no_wizard?(question); !yes_wizard?(question) end

def remove_gem(gem_name)
  gsub_file('Gemfile', /^gem\s+["']#{gem_name}["'].*$\n/, '')
  # or idented (group gems)
  gsub_file('Gemfile', /^  gem\s+["']#{gem_name}["'].*$\n/, '')
end

def remove_comments(file)
  gsub_file(file, /^\s*#.*\n/, '') # remove comments
end

def add_gem_to_development_and_test(gem_name, version_str = nil)
  version_str = ", '#{version_str}'" unless version_str.nil?
  insert_into_file 'Gemfile', "\n  gem '#{gem_name}'#{version_str}",
    after: 'group :development, :test do'
end

def source_paths
  Array(super) +
    [File.join(File.expand_path(File.dirname(__FILE__)), 'templates')]
end

include_errbit = yes_wizard?('Do you want to include "errbit"?')
if include_errbit
  errbit_host    = ask_wizard('errbit host? (ex: errbit.example.com)')
  errbit_port    = yes_wizard?('errbit host uses ssl?') ? 443 : 80
  errbit_api_key = ask_wizard('errbit API key for this project?')
end
include_bootstrap = yes_wizard?('Do you want to include "twitter bootstrap"?')
include_bower_rails = yes_wizard?('Do you want to include "bower-rails"? (requires node and bower package "npm install -g bower")')
include_capistrano = yes_wizard?('Do you want to include "capistrano"?')

say_recipe "Cleanup"

remove_comments 'Gemfile'
remove_comments 'config/routes.rb'
remove_comments 'config/database.yml'

remove_gem 'sdoc'
remove_gem 'turbolinks'
remove_gem 'byebug'
remove_gem 'web-console'

remove_file 'README.rdoc'
download_file "#{template_url}/README.md"

say_recipe 'Gems'

if include_bootstrap
  gem 'bootstrap-sass', '~> 3.3.1'
  gem 'autoprefixer-rails'
  gem 'font-awesome-rails'
end
gem 'bower-rails' if include_bower_rails
gem 'airbrake' if include_errbit

if include_capistrano
  gem 'capistrano'
  gem 'capistrano-rbenv'
  gem 'capistrano-bundler'
  gem 'capistrano-rails'
  gem 'capistrano-bundle_audit', require: false
  gem 'capistrano-db-tasks', require: false
end

gem 'rails-i18n', '~> 4.0.0'
gem 'haml-rails'
gem 'email_validator'

gem_group :development, :test do
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'quiet_assets'
  gem 'letter_opener'
  gem 'bullet'
  gem 'database_cleaner'
  gem 'rspec-rails', '~> 3.0'
  gem 'factory_girl_rails'
  gem 'shoulda-matchers'
  gem 'simplecov'
  gem 'simplecov-console'
  gem 'timecop'
end

run 'bundle install'

#
# RSPEC
#
say_recipe "rspec"
generate 'rspec:install'

inside 'spec' do
  remove_file 'spec_helper.rb'
  download_file "#{template_url}/spec/spec_helper.rb"
  remove_file 'rails_helper.rb'
  download_file "#{template_url}/spec/rails_helper.rb"
end

#
# BOWER-RAILS
#
if include_bower_rails
  say_recipe "bower"
  generate 'bower_rails:initialize'

  inside 'config' do
    inside 'initializers' do
      gsub_file 'bower_rails.rb', /^\s*# bower_rails.install_before_precompile.*\n/ do
  <<-BOWER
    bower_rails.install_before_precompile = true
  BOWER
      end
    end
  end
end

#
# AIRBRAKE/ERRBIT
#
if include_errbit
  say_recipe "errbit"
  inside 'config' do
    inside 'initializers' do
      create_file 'errbit.rb' do
<<-ERRBIT
Airbrake.configure do |config|
  config.api_key = '#{errbit_api_key}'
  config.host    = '#{errbit_host}'
  config.port    = #{errbit_port}
  config.secure  = config.port == 443
end
ERRBIT
      end
    end
  end
end

#
# CAPISTRANO
#
if include_capistrano
  say_recipe "capistrano"
  run 'bundle exec cap install STAGES=staging,production'
  insert_into_file 'Capfile', before: /^\s*# Load custom tasks.*'/ do
<<-CAPFILE
require 'capistrano/rbenv'
require 'capistrano/bundler'
require 'capistrano/bundle_audit'
require 'capistrano/rails'
require 'airbrake/capistrano3'
require 'capistrano-db-tasks'
CAPFILE
  end
  remove_comments 'Capfile'

  inside 'config' do
    remove_comments 'deploy.rb'

    insert_into_file 'deploy.rb', before: 'namespace :deploy do' do
<<-DEPLOY
# Default value for :linked_files is []
set :linked_files, %w{config/database.yml config/secrets.yml}

# Default value for linked_dirs is []
set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system public/uploads }

# Default value for keep_releases is 5
set :keep_releases, 10

# Capistrano DB settings
# ==============================================================================
# if you want to remove the local dump file after loading
set :db_local_clean, true

# if you want to remove the dump file from the server after downloading
set :db_remote_clean, true

# if you are highly paranoid and want to prevent any push operation to the server
set :disallow_pushing, true

DEPLOY
    end

    insert_into_file 'deploy.rb', after: 'namespace :deploy do' do
<<-DEPLOY

  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      execute :touch, release_path.join('tmp/restart.txt')
    end
  end

  after :publishing, :restart

  after 'deploy:finished', 'airbrake:deploy'
DEPLOY
    end

    inside 'deploy' do
      remove_file 'production.rb'
      create_file 'production.rb' do
<<-DEPLOY
set :rails_env, 'production'
set :branch,    'master'

set :deploy_to, '/home/deploy/rails'

# RBENV
set :rbenv_type,        :system
set :rbenv_custom_path, '/opt/rbenv'
set :rbenv_ruby,        '2.2.0'
DEPLOY
      end
      remove_file 'staging.rb'
      create_file 'staging.rb' do
<<-DEPLOY
set :rails_env, 'staging'
set :branch,    'develop'

set :deploy_to, '/home/deploy/rails'

# RBENV
set :rbenv_type,        :system
set :rbenv_custom_path, '/opt/rbenv'
set :rbenv_ruby,        '2.2.0'
DEPLOY
      end
    end
  end
end

#
# ASSETS
#
say_recipe "assets"
inside 'app' do
  inside 'assets' do
    inside 'javascripts' do
      scripts = ""
      scripts = "//= require bootstrap-sprockets\n" if include_bootstrap
      gsub_file 'application.js', /\/\/= require turbolinks/, scripts
    end
    inside 'stylesheets' do
      if include_bootstrap
        gsub_file 'application.css', /\*= require_tree ./ do
<<-STYLES
*
 * GEM COMPONENTS
 * -------------------------------------
 *= require font-awesome
 *
 * BOWER-RAILS COMPONENTS
 * -------------------------------------
 *
 * CUSTOM CSS
 * -------------------------------------
 *= require bootstrap_overrides
STYLES
        end
        download_file "#{template_url}/app/assets/stylesheets/bootstrap_overrides.scss"
      end
    end
  end
  inside 'views' do
    inside 'layouts' do
      remove_file 'application.html.erb'
      download_file "#{template_url}/app/views/layouts/application.html.haml"
    end
  end
end

say_recipe "configurations"
inside 'config' do
  # set correct timezone
  gsub_file 'application.rb', /^\s*# config.time_zone.*\n/, "    config.time_zone = 'Amsterdam'\n"

  # set nl locale
  gsub_file 'application.rb', /^\s*# config.i18n.default_locale.*\n/, "    config.i18n.default_locale = :nl\n"

  # some application configurations
  insert_into_file 'application.rb', after: /config.active_record.raise_in_transactional_callbacks.*\n/ do
<<-CONFIG

    # supported locales
    config.i18n.available_locales = [:nl, :en]

    # custom classes
    config.autoload_paths += %W(\#{config.root}\/lib)

    # skip generating helpers/view/javascript and stylesheets
    config.generators do |generate|
      generate.helper false
      generate.view_specs false
      generate.routing_specs false
      generate.request_specs false
      generate.javascript_engine false
      generate.stylesheets false
      generate.jbuilder false
    end
CONFIG
  end

  inside 'initializers' do
    insert_into_file 'assets.rb', after: '%w( search.js )' do
<<-ASSETS
\n\n# Shorthand for including images and fonts into the asset pipeline
Rails.application.config.assets.precompile.push(Proc.new do |path|
  File.extname(path).in? [
    '.png', '.gif', '.jpg', '.jpeg', '.svg', # Images
    '.eot', '.otf', '.svc', '.woff', '.ttf', # Fonts
  ]
end)
ASSETS
    end

    # also filter out password_confirmation attributes
    gsub_file 'filter_parameter_logging.rb', /s*:password/, ":password, :password_confirmation"
  end

  inside 'environments' do
    gsub_file 'production.rb', /config.log_level = :debug/, "config.log_level = :info"
    insert_into_file 'production.rb', after: "# config.logger = ActiveSupport::TaggedLogging.new(SyslogLogger.new)\n" do
"
  # Log to environment log file, keep 7, max size 100mb
  config.logger = ActiveSupport::TaggedLogging.new(Logger.new(Rails.root.join(\"log\", Rails.env + \".log\"), 7, 104857600))
"
    end
    run "cp production.rb staging.rb" if include_capistrano

    insert_into_file 'development.rb', after: '# config.action_view.raise_on_missing_translations = true' do
<<-DEVENV
\n\n  # Bullet configuration
  config.after_initialize do
    Bullet.enable = true
    Bullet.bullet_logger = true
    Bullet.rails_logger = true
  end

  # Server mails through letter_opener
  config.action_mailer.default_url_options = { host: 'localhost:3000' }
  config.action_mailer.delivery_method = :letter_opener
DEVENV
    end
  end

  inside 'locales' do
    %w{nl.yml en.yml models.nl.yml models.en.yml}.each do |file|
      download_file "#{template_url}/locales/#{file}"
    end
  end
end

say_recipe "git"
remove_file '.gitignore'
download_file "#{template_url}/.gitignore"

git :init
git add: "."
git commit: "-aqm 'Initial commit'"
git checkout: '-b develop'