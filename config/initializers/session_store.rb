# Be sure to restart your server when you modify this file.

OreNoIgoogle::Application.config.session_store :cookie_store, 
	key: '_ore_no_igoogle_session', expire_after: 1.months,
	:domain => :all, :httponly => false
