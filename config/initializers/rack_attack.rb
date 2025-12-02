class Rack::Attack
  # Allow all requests from localhost
  safelist('allow-localhost') do |req|
    '127.0.0.1' == req.ip || '::1' == req.ip
  end
  BAD_IPS = ["84.95.84.30", "147.189.171.165", "20.171.0.0/16"]
  Rack::Attack.blocklist "Block IPs from Environment Variable" do |req|
    BAD_IPS.include?(req.ip) || req.path.index('&gt&gt')
  end
  # Throttle requests to 100 requests per 3 minutes per IP
  throttle('req/ip', limit: 100, period: 3.minutes) do |req|
    req.ip unless req.path.start_with?('/assets')
  end
end
