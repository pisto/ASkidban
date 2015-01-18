This is a reboot of the failed project kidban, a system to ban proxies using whois data. The new thing is that this uses information related to [Autonomous Systems](http://en.wikipedia.org/wiki/Autonomous_System_%28Internet%29) (AS).

#Method#
Put simply, kidban is an aid in automatizing the review and managing bans of AS. The intended usage is to ban VPN and hosting providers (that can be used as proxies), leaving out all the ISP that provide end-user access to the Internet. The actual IP ranges to ban are fetched from a public [looking glass](http://en.wikipedia.org/wiki/Looking_Glass_server) service.

It is theoretically possible to review all the AS in the world, but the approach used here is to seed the list of AS of interest from the IPs that your online service actually sees, or from lists of known proxies.

The workflow of ASkidban is divided in three steps: hits, decide, compile.

###Seed the ASN list###
You first import IP and turnresolve their ASN:
```bash
./ASkidban.lua -g /path/to/GeoIPASNum2.csv hits < my_hits_list
```
`GeoIPASNum2.csv` is the [CSV GeoLite ASN](http://download.maxmind.com/download/geoip/database/asnum/GeoIPASNum2.zip) database. `my_hits_list` is a list of IPs in dotted form, one per line.

###Decide the tags###

You review the AS with the following command:
```bash
./ASkidban.lua decide
```
This will bring up an interactive console, which will present to you the AS and their whois message in a summarized form (highlighting interesting words, ellipsizing unneded info and gathering URLs), and [PeeringDB](https://www.peeringdb.com/) information. Each ASN is either *dunno* (blue, undecided), *sir* (green, good) or *kid* (red, bad). Your job is to tag *dunnos* into *kids* or *sirs* (so that ASkidban will not ask you about them anymore). Here is a screenshot of how it looks like:
![A clearly bad ASN](http://i.imgur.com/EIcAjTj.png)

Since this is clearly a *kid*, let us tag it so hitting `k`:
![Tagged as kid](http://i.imgur.com/2Ej5T0H.png)

Refer to the built-in help for more info on how to navigate through the AS.

Tagging an ASN simply means moving the associated file around in the `db/` folder. For example, if you tag ASN 1 from *dunno* to *kid*, ASkidban will simply rename `db/dunno/1` to `db/kids/1`.

###Compile the ban list###

Run the following command:
```bash
./ASkidban.lua compile
```
and you get three compiled lists:
* `compiled/AS`: list of *kids*
* `compiled/ipv4`: list of IP ranges associated to *kids*
* `compiled/ipv4_compact`: same as `compiled/ipv4` but the IP range is encoded as `ip * 0x40 + mask`, and printed in decimal format.

The compile step makes use of the looking glass of [Hurricane Electric](http://bgp.he.net/), through this [API](https://www.enjen.net/asn-blocklist/).

#Dependencies#

Lua 5.2 or luajit, and luarocks modules `json`, `lua-curl`, `luafilesystem`.

#Current database status#

The database embed in this repo should not be used in "production" servers yet, as I am still deciding the exact definition of what is a *kid* or a *sir*. You can of course fork this repository, reset the `db/{dunno,kids,sirs}` folders (or move all files to `db/dunno`), and start from scratch.
