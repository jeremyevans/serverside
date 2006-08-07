class DefaultController < Controller.mount(:path => '/')
  def process(request)
    @request = request
    request.render 'Hey there people.'
  end
end

class SharonController < Controller.mount(:path => '/sharon')
  def process(request)
    @request = request
    request.render 'Sharon mau...'
  end
end
