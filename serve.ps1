# Servidor estatico minimo para previsualizar la web en http://localhost:8080
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 8080)
$listener.Start()
Write-Host "Sirviendo $root en http://localhost:8080"

$mime = @{
  ".html"="text/html; charset=utf-8"; ".css"="text/css"; ".js"="application/javascript";
  ".png"="image/png"; ".jpg"="image/jpeg"; ".jpeg"="image/jpeg"; ".svg"="image/svg+xml";
  ".ico"="image/x-icon"; ".pdf"="application/pdf"; ".webp"="image/webp"; ".json"="application/json";
  ".woff"="font/woff"; ".woff2"="font/woff2"
}

while ($true) {
  $client = $listener.AcceptTcpClient()
  try {
    $stream = $client.GetStream()
    $reader = New-Object System.IO.StreamReader($stream)
    $requestLine = $reader.ReadLine()
    while (($line = $reader.ReadLine()) -and $line -ne "") { }
    if (-not $requestLine) { continue }
    $path = ($requestLine -split ' ')[1].Split('?')[0]
    if ($path -eq "/") { $path = "/index.html" }
    $path = [System.Uri]::UnescapeDataString($path)
    $file = Join-Path $root ($path.TrimStart('/') -replace '/', '\')
    $fullRoot = [System.IO.Path]::GetFullPath($root)
    $fullFile = try { [System.IO.Path]::GetFullPath($file) } catch { "" }
    if ($fullFile -and $fullFile.StartsWith($fullRoot) -and (Test-Path $fullFile -PathType Leaf)) {
      $bytes = [System.IO.File]::ReadAllBytes($fullFile)
      $ext = [System.IO.Path]::GetExtension($fullFile).ToLower()
      $type = $mime[$ext]; if (-not $type) { $type = "application/octet-stream" }
      $header = "HTTP/1.1 200 OK`r`nContent-Type: $type`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`n`r`n"
    } else {
      $bytes = [System.Text.Encoding]::UTF8.GetBytes("404 - No encontrado")
      $header = "HTTP/1.1 404 Not Found`r`nContent-Type: text/plain; charset=utf-8`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`n`r`n"
    }
    $hb = [System.Text.Encoding]::ASCII.GetBytes($header)
    $stream.Write($hb, 0, $hb.Length)
    $stream.Write($bytes, 0, $bytes.Length)
    $stream.Flush()
  } catch {} finally { $client.Close() }
}
