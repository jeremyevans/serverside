class DefaultController < Controller.mount(:path => '/')
  def process(request)
    request.render request.env.inspect
  end
end

class SharonController < Controller.mount(:path => '/sharon')
  def process(request)
    request.render 'Sharon mau...'
  end
end

class EylonController < Controller.mount {|r| r.path == '/eylon'}
  def process(request)
    request.render 'Eylon mau...'
  end
end
