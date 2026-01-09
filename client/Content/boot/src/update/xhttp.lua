local Downloader = require("boot.src.update.Downloader")

local downloader = Downloader.new()

function xhttp_request(...)
    downloader:download(...)
end

return downloader