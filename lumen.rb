cask 'lumen' do
  version '1.0.0'
  sha256 'd5ad8dea570063860086df09802cde876070ec7b28694f292e0aa3ce333a1ef9'

  url "https://github.com/anishathalye/lumen/releases/download/v#{version}/lumen.zip"
  name 'Lumen'
  homepage 'https://github.com/anishathalye/lumen/'
  license :gpl

  app 'Lumen.app'

  postflight do
    suppress_move_to_applications key: 'suppressMoveToApplications'
  end
end
