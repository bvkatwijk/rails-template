# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path
Rails.application.config.assets.paths << Rails.root.join('vendor', 'assets', 'images')

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in app/assets folder are
# already added.
# Rails.application.config.assets.precompile += %w( search.js )

# Short hand for adding images and font's into the asset pipeline
Rails.application.config.assets.precompile << proc do |path|
  true if path =~ /\.(png|gif|jpg|svg|eot|otf|svc|woff|ttf|)\z/
end
