#lang racket

(require (planet dmac/spin))
(require db)
(require db/util/datetime)
(require srfi/19)
(require json)

(define c
  (virtual-connection 
   (lambda ()
     (postgresql-connect #:server "localhost"
                      #:port 5432
                      #:database "sd_ventures_development"
                      #:user "sd_ventures"
                      #:password ""))))


(get "/api/1/devices"
  (lambda (req)
    (let* ([recs (query-rows c "SELECT mac_addr FROM devices")]
          [mac-addrs (map (lambda (rec) (make-hasheq (list (cons 'mac-addr (vector-ref rec 0))))) recs)])
      (jsexpr->string mac-addrs))))


(get "/api/1/devices/:device_id"
  (lambda (req)
    (let* ([device-mac-addr (params req 'device_id)]
           [rec (query-maybe-row c "SELECT manufactured_at FROM devices WHERE mac_addr = $1" device-mac-addr)])
      (if rec
          (let ([manufactured-at (date->string (sql-datetime->srfi-date (vector-ref rec 0)))])
            (jsexpr->string (make-hasheq (list (cons 'mac-addr device-mac-addr) (cons 'manufactured-at manufactured-at)))))
          "Device does not exist"))))


(get "/api/1/devices/:device_id/readings"
  (lambda (req)
    (let* ([device-mac-addr (params req 'device_id)]
           [rec (query-maybe-row c "SELECT 1 FROM devices WHERE mac_addr = $1" device-mac-addr)])
      ; if the device record exists, only then get the readings
      (if rec
          (let* ([reading-recs (query-rows c "SELECT value, created_at FROM readings WHERE device_mac_addr = $1" device-mac-addr)]
                 [rec-strings (map (lambda (rec)
                                     (make-hasheq (list (cons 'value (vector-ref rec 0))
                                                        (cons 'created-at (date->string (sql-datetime->srfi-date (vector-ref rec 1)))))))
                                   reading-recs)])
            (jsexpr->string rec-strings))
          "Device does not exist"))))

(run)
