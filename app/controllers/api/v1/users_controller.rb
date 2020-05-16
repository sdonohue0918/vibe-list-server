class Api::V1::UsersController < ApplicationController
skip_before_action :authorized, only: [:create]

  def index
    @users = User.all
    render json: @users
  end

  def create
    if params[:error]
      puts 'LOGIN ERROR', params
      redirect_to ENV['REACT_APP_BASE_URL']
    else
      body = {
        grant_type: "authorization_code",
        code: params[:code],
        redirect_uri: "#{ENV['API_BASE_URL']}/api/v1/logging-in",
        client_id: ENV['CLIENT_ID'],
        client_secret: ENV['CLIENT_SECRET']
      }

      auth_response = RestClient.post('https://accounts.spotify.com/api/token', body)

      auth_params = JSON.parse(auth_response.body)

      header = {
        Authorization: "Bearer #{auth_params["access_token"]}"
      }
      user_response = RestClient.get("https://api.spotify.com/v1/me", header)

      user_params = JSON.parse(user_response.body)

      if user_params["images"]
        profile_pic = user_params["images"][0]["url"]
      end

      @user = User.find_or_create_by(
        username: user_params["id"],
        spotify_url: user_params["external_urls"]["spotify"],
        href: user_params["href"],
        uri: user_params["uri"],
        profile_image: profile_pic,
        display_name: user_params["display_name"]
      )
      @user.update(access_token: auth_params["access_token"], refresh_token: auth_params["refresh_token"])

      token = encode_token(user_id: @user.id)

      response_query_params = {
        jwt: token
      }

      redirect_to "#{ENV['REACT_APP_BASE_URL']}/welcome?#{response_query_params.to_query}"
    end
  end

  def logged_in_user
    current_user ? (render json: current_user, root: 'data', serializer: UserSerializer) : (render json: {message: 'User not found'}, status: 404)
  end
end
