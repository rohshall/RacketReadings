#lang racket

(require (planet dmac/spin))
(require db)
(require db/util/datetime)
(require srfi/19)

(define c
  (virtual-connection 
   (lambda ()
     (printf "connecting!")
     (postgresql-connect #:server "localhost"
                      #:port 5432
                      #:database "sd_ventures_development"
                      #:user "sd_ventures"
                      #:password ""))))


(get "/api/1/devices"
  (lambda (req)
    (let* ([recs (query-rows c "SELECT mac_addr FROM devices")]
          [mac-addrs (map (lambda (rec) (vector-ref rec 0)) recs)])
      (foldl (lambda (response mac-addr) (string-append response "\n" mac-addr)) "" mac-addrs))))


(get "/api/1/devices/:device_id"
  (lambda (req)
    (let* ([device-mac-addr (params req 'device_id)]
           [rec (query-maybe-row c "SELECT manufactured_at FROM devices WHERE mac_addr = $1" device-mac-addr)])
      (if rec
        (string-append "Device " device-mac-addr " manufactured at: " (date->string (sql-datetime->srfi-date (vector-ref rec 0))))
        "Device does not exist"))))


(get "/api/1/devices/:device_id/readings"
  (lambda (req)
    (let* ([device-mac-addr (params req 'device_id)]
           [rec (query-maybe-row c "SELECT 1 FROM devices WHERE mac_addr = $1" device-mac-addr)])
      (if rec
          (let* ([reading-recs (query-rows c "SELECT value, created_at FROM readings WHERE device_mac_addr = $1" device-mac-addr)]
                 [rec-strings (map (lambda (rec) (string-append "value: " (vector-ref rec 0) " created at: " (date->string (sql-datetime->srfi-date (vector-ref rec 1))))) reading-recs)])
            (foldl (lambda (response rec-string) (string-append response "\n" rec-string)) "" rec-strings))
          "Device does not exist"))))

(run)
