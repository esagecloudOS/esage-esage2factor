require "abiquo-api"
require "resque"
require "securerandom"
require "mail"
require "./token"

# Resque background task
class Validate

  @queue = :validate

  def self.perform(token_id)
    begin
      $token = Token.get(token_id)
      
      abiquo = AbiquoAPI.new( :abiquo_api_url => APP_CONFIG['abiquo']['api_url'], 
                              :abiquo_username => APP_CONFIG['abiquo']['api_user'], 
                              :abiquo_password => APP_CONFIG['abiquo']['api_pass'],
                              :connection_options => { :connect_timeout => 15 })
      
      user_link = AbiquoAPI::Link.new(:href => "/api/admin/enterprises/#{$token.enterprise_id}/users/#{$token.user_id}", :type => 'application/vnd.abiquo.user+json', :client => abiquo)
      user = user_link.get
      if !user.active
        user.active = true
        user.update
      end

      $token.update(:updated_at => Time.now, :enabled => true, :status => 'VALIDATED')
      $token.save
    rescue => e
      update_token_status('VALIDATION_ERROR',$token.token_id)
    end
  end

end