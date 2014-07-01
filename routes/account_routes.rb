require 'trello'

class Ollert
  post '/authenticate' do
    user = User.find_by email: params['email']
    if user.nil?
      flash[:warning] = "Email address #{params['email']} does not appear to be registered."
      redirect :login
    elsif !user.authenticate? params['password']
      flash[:warning] = "I didn't find that username/password combination. Check your spelling."
      redirect :login
    else
      flash[:success] = "Welcome back."
      session[:user] = user.id
      redirect '/'
    end
  end

  get '/signup' do
    haml_view_model :signup, @user
  end

  post '/signup' do
    user = User.new :email => params[:email]
    user.password = params[:password]

    if params[:agreed] && user.save
      session[:user] = user.id
      flash[:success] = "You're signed up! Click below to connect with Trello for the first time."
      redirect '/'
    else
      @email = params[:email]
      if !params[:agreed]
        flash[:error] = "Please agree to the terms of service."
      elsif user.errors.any?
        error_list = ""
        user.errors.full_messages.each { |x| error_list << "<li>#{x}</li>" }
        flash[:error] = "Registration failed: <ul>#{error_list}</ul>"
      else
        flash[:error] = "Something's broken, please try again later."
      end
      
      haml_view_model :signup
    end
  end

  get '/login' do
    haml_view_model :login
  end

  post '/logout', :auth => :authenticated do
    session[:user] = nil
    session[:token] = nil
    flash[:success] = "Come see us again soon!"

    redirect '/'
  end

  put '/settings/trello/disconnect', :auth => :authenticated do
    @user.member_token = nil
    @user.trello_name = nil

    if !@user.save
      return 500
    end

    return 200
  end

  put '/settings/trello/connect', :auth => :authenticated do
    session[:token] = params[:token]

    client = get_client ENV['PUBLIC_KEY'], session[:token]

    token = client.find(:token, session[:token])
    member = token.member

    @user.member_token = session[:token]
    @user.trello_name = member.attributes[:username]

    if !@user.save
      return 500
    else
      @trello_name = @user.trello_name
      return 200
    end
  end

  post '/settings/email', :auth => :authenticated do
    @user.email = params[:email]

    if @user.save
      flash[:success] = "Your new email is #{@user.email}. Use this to log in!"
    else
      if @user.errors.any?
        error_list = ""
        @user.errors.full_messages.each { |x| error_list << "<li>#{x}</li>" }
        flash[:error] = "Could not update email: <ul>#{error_list}</ul>"
      else
        flash[:error] = "Something's broken, please try again later."
      end
    end

    redirect '/settings'
  end

  post '/settings/password', :auth => :authenticated do
    result = @user.change_password params[:current_password],
                               params[:new_password],
                               params[:confirm_password]
    if result[:status]
      if !@user.save
        if @user.errors.any?
          error_list = ""
          user.errors.full_messages.each { |x| error_list << "<li>#{x}</li>" }
          flash[:error] = "Could not update password: <ul>#{error_list}</ul>"
        else
          flash[:error] = "Password could not be updated."
        end
      else
        flash[:success] = "Password has been changed."
      end
    else
      flash[:error] = result[:message]
    end

    redirect '/settings'
  end

  post '/settings/delete', :auth => :authenticated do
    if params[:iamsure] == "on"
      email = @user.email

      session[:user] = nil
      session[:token] = nil
      if @user.delete
        flash[:success] = "User with login of #{email} has been deleted. Come back and sign up again one day!"
        redirect '/'
      else
        flash[:error] = "I wasn't able to delete that user. Do you mind trying again?"
        redirect '/settings'
      end
    else
      flash[:warning] = "You must check the 'I am sure' checkbox to delete your account."
      redirect '/settings'
    end
  end

  get '/settings', :auth => :authenticated do
    @trello_name = @user.trello_name
    haml_view_model :settings, @user
  end
end