require "sinatra"
require "resque"
require "abiquo-api"
require 'json'
require 'active_support/time'
require "./token"
require "./workers/tokenize"
require "./workers/validate"

# Token status
# CREATED : Token has been created but hasn't been processed yet
# PROCESSING : Token is being procesed by resque tasks
# VALIDATION_ERROR : Unable to validate token
# CONNECTION_ERROR : Problem during connection to Abiquo API
# DELIVERY_ERROR : Problem during token email delivery
# LOOKUP_ERROR : Pair username-email not found in Abiquo
# EXPIRED_ERROR : Token expired
# MATCH_ERROR : Validate form token id and token does not match
# SECURITY_ERROR : Creation token IP and validate token IP does not match
# CONSUMED_ERROR : Token has been already used

# Check if token is expired or alive
# True => token is expired
# False => token is alive
def token_exipred(created_at)
  ((created_at + APP_CONFIG['abiquo']['token_timeout'].to_i.seconds) < Time.now) ? true : false
end

class Abiquo2FA < Sinatra::Base


  get "/" do
    erb :login
  end

	post "/token/?" do
    begin
      $token = Token.new( :token => SecureRandom.uuid,
                          :created_at => Time.now,
                          :updated_at => Time.now,
                          :username => params[:username],
                          :email => params[:email],
                          :ip_address => request.ip,
                          :status => 'PROCESSING')
      $token.save

      Resque.enqueue(Tokenize, params[:username], params[:email], $token.token_id)
      erb :tokenize, :locals => { :token_id => $token.token_id, :abiquo_login_url => APP_CONFIG['abiquo']['abiquo_login_url'] }
    rescue => e
      update_token_status('VALIDATION_ERROR',$token.token_id)
      erb :error, :locals => { :token_status => $token.status }
    end
	end

  # Resource to validate token and activate Abiquo user
  post "/validate/?" do
    begin
      $token = Token.get(params[:token_id])
      raise 'CONSUMED_ERROR' if ($token.enabled)
      raise 'MATCH_ERROR' if ($token.token != params[:token])
      raise 'SECURITY_ERROR' if ($token.ip_address != request.ip)
      raise 'EXPIRED_ERROR' if (token_exipred($token.created_at))
      if $token.status == 'SENT'
        begin
          update_token_status('PROCESSING',$token.token_id)
          Resque.enqueue(Validate, $token.token_id)
          erb :validate, :locals => { :token_id => $token.token_id, :abiquo_login_url => APP_CONFIG['abiquo']['abiquo_login_url'] }
        rescue => e
          update_token_status('VALIDATION_ERROR',$token.token_id)
          erb :error, :locals => { :token_status => $token.status }
        end
      else
        erb :error, :locals => { :token_status => $token.status }
      end
    rescue => e
      update_token_status(e.message,$token.token_id)
      erb :error, :locals => { :token_status => $token.status }
    end
  end

  # Resource to track token request status
  get "/status/:token_id" do
    content_type :json
    begin
      $token = Token.get(params[:token_id])

      if (token_exipred($token.created_at))
        '{"status" : "EXPIRED_ERROR"}'
      else
        '{"status" : "'+$token.status+'"}'
      end
    rescue => e
      '{"status" : "UNEXPECTED_ERROR"}'
    end
  end

end