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

(get "/api/1/devices/:device_id"
  (lambda (req)
    (let* ([device-mac-addr (params req 'device_id)]
           [rec (query-row c "SELECT manufactured_at FROM devices WHERE mac_addr = $1" device-mac-addr)]
           [manufactured-at (sql-datetime->srfi-date (vector-ref rec 0))])
      (string-append "Device " device-mac-addr " manufactured at: " (date->string manufactured-at)))))

(run)