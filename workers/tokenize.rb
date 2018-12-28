require "abiquo-api"
require "resque"
require "securerandom"
require "mail"
require "./token"

def send_token(token,email)
  begin
    options = { :address              => APP_CONFIG['smtp']['smtp_server'],
                :port                 => APP_CONFIG['smtp']['smtp_port'],
                :user_name            => APP_CONFIG['smtp']['smtp_user'],
                :password             => APP_CONFIG['smtp']['smtp_pass'],
                :authentication       => 'plain',
                :enable_starttls_auto => true  }

    Mail.defaults do
      delivery_method :smtp, options
    end

    Mail.deliver do
      to       email
      from     APP_CONFIG['smtp']["mail_from"]
      subject  APP_CONFIG['smtp']["mail_subject"]
      body     "Token: #{token}"
    end
  rescue => e
    puts e
  end
end 

# Resque background task
class Tokenize

  @queue = :tokenize

  def self.perform(username,email,token_id) 
    begin
      $token = Token.get(token_id)
      abiquo = AbiquoAPI.new( :abiquo_api_url => APP_CONFIG['abiquo']['api_url'], 
                              :abiquo_username => APP_CONFIG['abiquo']['api_user'], 
                              :abiquo_password => APP_CONFIG['abiquo']['api_pass'],
                              :connection_options => { :connect_timeout => 15 })

      enterprises_link = AbiquoAPI::Link.new(:href => '/api/admin/enterprises', :type => 'application/vnd.abiquo.enterprises+json', :client => abiquo)
      enterprises = enterprises_link.get

      $found = false
      $user_id = nil
      $enterprise_id = nil
      enterprises.each do |enterprise|
        users = enterprise.link(:users).get
        users.each do |user|
          if (user.email == email && user.nick == username)
            $user_id = user.id
            $enterprise_id = enterprise.id
            $found = true
            break
          end
        end
        break if $found
      end
      if $found
        if APP_CONFIG['abiquo']['exclude_users'].include? $user_id
          update_token_status('REDIRECT',$token.token_id)
        else
          begin
            $token.update(:updated_at => Time.now, :user_id => $user_id, :enterprise_id => $enterprise_id)
            $token.save
            send_token($token.token,$token.email)
            update_token_status('SENT',$token.token_id)
          rescue => e
            update_token_status('DELIVERY_ERROR',$token.token_id)
          end
        end
      else
        update_token_status('LOOKUP_ERROR',$token.token_id)
      end
    rescue => e
      update_token_status('CONNECTION_ERROR',$token.token_id)
    end
  end

end