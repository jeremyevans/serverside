$config[:server_ports] = 8000..8000

DB_CONNECTIONS[:production] = {
  :adapter => 'postgresql',
  :database => 'reality',
  :username => 'postgres',
  :password => '240374'
}

DB_CONNECTIONS[:development] = {
  :adapter => 'postgresql',
  :database => 'reality_development',
  :username => 'postgres',
  :password => '240374'
}

DB_CONNECTIONS[:test] = {
  :adapter => 'postgresql',
  :database => 'reality_test',
  :username => 'postgres',
  :password => '240374'
}
