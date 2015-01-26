backend default {
    .host = "127.0.0.1";
    .port = "20080";
}

sub vcl_recv {
    set req.hash_ignore_busy = true;
    if (req.restarts == 0) {
        if (req.http.x-forwarded-for) {
            set req.http.X-Forwarded-For =
                req.http.X-Forwarded-For + ", " + client.ip;
        } else {
            set req.http.X-Forwarded-For = client.ip;
        }
     }

     if (req.request != "GET" && req.request != "HEAD") {
         /* We only deal with GET and HEAD by default */
         error 403 "Forbidden Method";
     }

     set req.backend = default;
     set req.grace = 1h;

     return (lookup);
}

sub vcl_hash {
/***
    hash_data(req.url);
    if (req.http.host) {
        hash_data(req.http.host);
    } else {
        hash_data(server.ip);
    }
***/

///    if (req.url ~ "\?") {
///        set req.http.X-TMP = regsub(req.url, "^([^?]+).*", "\1");
        //// DELETE parameter
        set req.http.X-TMP = regsub(req.url, "\?.*$", "");
        hash_data(req.http.X-TMP);
        remove req.http.X-TMP;
///    }

    return (hash);
}

sub vcl_fetch {
     set beresp.grace = 1h;
    set beresp.ttl = 10s;

    if (beresp.status >= 400 && beresp.status < 500) {
         set beresp.ttl = 20s;
    }

    if (beresp.status >= 500 && beresp.status < 600) {
         set beresp.saintmode = 90s;
         return (restart);
    }

    // 圧縮されていない場合、圧縮する
    set beresp.do_gzip = true;

    // 圧縮されている場合、解凍する
    // set beresp.do_gunzip = true;

    return (deliver);
}

sub vcl_deliver {
    if(obj.hits > 0){
        set resp.http.X-Cache = "Hit";
    } else {
        set resp.http.X-Cache = "Miss";
    }
}

sub vcl_error {
    if((obj.status >= 100 && obj.status < 200)
    || obj.status == 204
    || obj.status == 304){
        return (deliver);
    }

    set obj.http.Content-Type = "text/html; charset=utf-8";
    set obj.http.Retry-After = "5";
    synthetic {"
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
 "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html>
  <head>
    <title>"} + obj.status + " " + obj.response + {"</title>
  </head>
  <body>
    <h1>Error "} + obj.status + " " + obj.response + {"</h1>
  </body>
</html>
"};
    return (deliver);
}
