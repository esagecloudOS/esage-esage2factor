require "abiquo-api"
require "active_support/time"
require "./token"

def session_expired(created_at)
  ((created_at + APP_CONFIG['abiquo']['session_timeout'].to_i.seconds) < Time.now) ? true : false
end

desc "Disable Abiquo users which session has expired."
task :expire_sessions do

  abiquo = AbiquoAPI.new( :abiquo_api_url => APP_CONFIG['abiquo']['api_url'], 
                          :abiquo_username => APP_CONFIG['abiquo']['api_user'], 
                          :abiquo_password => APP_CONFIG['abiquo']['api_pass'],
                          :connection_options => { :connect_timeout => 30 })

  enterprises_link = AbiquoAPI::Link.new(:href => '/api/admin/enterprises', :type => 'application/vnd.abiquo.enterprises+json', :client => abiquo)
  enterprises = enterprises_link.get

  enterprises.each do |enterprise|
    users = enterprise.link(:users).get
    users.each do |user|
      force_expire = false
      if !APP_CONFIG['abiquo']['exclude_users'].include? user.id
        token = Token.last(:enterprise_id => enterprise.id, :user_id => user.id)
        if token
          force_expire = session_expired(token.created_at)
          update_token_status('EXPIRED',token.token_id)
        else
          force_expire = true
        end
      end
      if force_expire && user.active
        puts "Disabling user #{user.id} - #{user.email}"
        user.active = false
        user.update
      end
    end
  end

end