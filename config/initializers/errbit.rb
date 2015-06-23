Airbrake.configure do |config|
  config.api_key = "#{ENV['ERRBIT_API_KEY']}"
  config.host    = "#{ENV['ERRBIT_HOSTNAME']}"
  config.port    = 443
  config.secure  = config.port == 443
end