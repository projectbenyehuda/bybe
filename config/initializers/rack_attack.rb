class Rack::Attack
  # Allow all requests from localhost
  safelist('allow-localhost') do |req|
    '127.0.0.1' == req.ip || '::1' == req.ip
  end

  # Allow all requests from logged-in users
  safelist('allow-logged-in-users') do |req|
    # Check if user is logged in via session
    req.session['user_id'].present?
  end
  BAD_IPS = ["147.189.171.165", '47.80.0.0/13', '47.76.0.0/14','47.74.0.0/15'] # Alibaba cloud, which has been pounding our server inconsiderately (and probably uselessly)
  Rack::Attack.blocklist "Block IPs from Environment Variable" do |req|
    BAD_IPS.include?(req.ip)
  end
  # Throttle requests to 100 requests per 3 minutes per IP
  throttle('req/ip', limit: 100, period: 3.minutes) do |req|
    req.ip unless req.path.start_with?('/assets')
  end
end
