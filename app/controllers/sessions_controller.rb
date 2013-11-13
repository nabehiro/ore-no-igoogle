class SessionsController < ApplicationController
  def callback
    auth = request.env["omniauth.auth"]
    user = User.find_by_provider_and_uid(auth["provider"], auth["uid"]) || User.create_with_omniauth(auth)

    session[:user_id] = user.id
    redirect_to '/'
  end

  def destroy
  	reset_session
    cookies[Rails.application.config.session_options[:key]] = { value: "", expires: Time.now - 3600 }
    redirect_to '/'
  end

  def get_user
  	user = User.find(session[:user_id]) if session[:user_id]
  	if user
  		render :json => json_hash(user)
  	else
  		render :json => nil
  	end
  end 

  def set_info
  	user = User.find(session[:user_id]) if session[:user_id]
  	if user
  		user.info = params[:info]
  		user.save!
      render :json => json_hash(user)
  	else
  		render :json => nil
  	end
  end

  private
  def json_hash(user)
      {
        name: user.name,
        provider: user.provider,
        info: (JSON.parse(user.info) rescue nil),
        token: form_authenticity_token
      }
  end
end


