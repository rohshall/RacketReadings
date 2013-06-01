#lang racket

(require (planet dmac/spin)
         db
         db/util/datetime
         srfi/19
         json
         web-server/http/request-structs)

(define c
  (virtual-connection 
   (lambda ()
     (postgresql-connect #:server "localhost"
                      #:port 5432
                      #:database "sd_ventures_development"
                      #:user "sd_ventures"
                      #:password ""))))

(define json-h (header #"Content-Type" #"application/json"))

(get "/api/1/devices"
  (lambda (req)
    (let* ([st "SELECT device_type_id, mac_addr FROM devices"]
           [recs (query-rows c st)]
          [mac-addrs (map (lambda (rec)
                            (make-hasheq (list (cons 'device-type-id (vector-ref rec 0))
                                               (cons 'mac-addr (vector-ref rec 1)))))
                          recs)])
      `(200 (,json-h) ,(jsexpr->string mac-addrs)))))


(post "/api/1/devices"
  (lambda (req)
    (let* ([st "INSERT INTO devices (device_type_id, mac_addr, manufactured_at) VALUES ($1, $2, $3)"]
           [json-body (string->jsexpr (bytes->string/utf-8 (request-post-data/raw req)))]
           [mac-addr (hash-ref json-body 'mac_addr)]
           [device-type-id (hash-ref json-body 'device_type_id)]
           [manufactured-at (srfi-date->sql-timestamp (seconds->date (current-seconds)))])
      (query-exec c st device-type-id mac-addr manufactured-at)
      `(200 (,json-h) ,(jsexpr->string (make-hasheq (list (cons 'status "ok"))))))))


(get "/api/1/devices/:device_id"
  (lambda (req)
    (let* ([device-mac-addr (params req 'device_id)]
           [st "SELECT device_type_id, manufactured_at FROM devices WHERE mac_addr = $1"]
           [rec (query-maybe-row c st device-mac-addr)])
      (if rec
          (let ([manufactured-at (date->string (sql-datetime->srfi-date (vector-ref rec 1)))])
            `(200 (,json-h) ,(jsexpr->string (make-hasheq (list (cons 'device-type-id (vector-ref rec 0))
                                                                (cons 'manufactured-at manufactured-at))))))
          `(200 (,json-h) "Device does not exist")))))


(get "/api/1/devices/:device_id/readings"
  (lambda (req)
    (let* ([device-mac-addr (params req 'device_id)]
           [st "SELECT 1 FROM devices WHERE mac_addr = $1"]
           [rec (query-maybe-row c st device-mac-addr)])
      ; if the device record exists, only then get the readings
      (if rec
          (let* ([st "SELECT value, created_at FROM readings WHERE device_mac_addr = $1"]
                 [reading-recs (query-rows c st device-mac-addr)]
                 [rec-strings (map (lambda (rec)
                                     (make-hasheq (list (cons 'value (vector-ref rec 0))
                                                        (cons 'created-at (date->string (sql-datetime->srfi-date (vector-ref rec 1)))))))
                                   reading-recs)])
            `(200 (,json-h) ,(jsexpr->string rec-strings)))
          `(200 (,json-h) "Device does not exist")))))


(post "/api/1/devices/:device_id/readings"
  (lambda (req)
    (let* ([device-mac-addr (params req 'device_id)]
           [st "SELECT 1 FROM devices WHERE mac_addr = $1"]
           [rec (query-maybe-row c st device-mac-addr)])
      ; if the device record exists, only then get the readings
      (if rec
          (let* ([st "INSERT INTO readings (value, created_at, device_mac_addr) VALUES ($1, $2, $3)"]
                 [json-body (string->jsexpr (bytes->string/utf-8 (request-post-data/raw req)))]
                 [value (hash-ref json-body 'value)]
                 [created-at (srfi-date->sql-timestamp (seconds->date (current-seconds)))])
            (query-exec c st value created-at device-mac-addr)
            `(200 (,json-h) ,(jsexpr->string (make-hasheq (list (cons 'status "ok"))))))
          `(200 (,json-h) "Device does not exist")))))

(run)
