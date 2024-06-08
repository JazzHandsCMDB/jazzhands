
*NOTE* - This proabbly wants to be revamped to make sense.

IP addresses manaegment and sanity enforcement are one of the big features
that the database provides.    The three most interesting knobs are the
netblock_type the ip_universe, and the ip_namespace.

The netblock table contains all IP addresses and netblocks.  The can_subnet
and is_single_address columns differentiate between the different varities.
If "can_subnet" is set, it means it's more of an administrative groupigns of
IP addresses, and children of that network must not be single addreses.

For a given netblock to contain single IPs, it must have can_subnet turned off.
This would typically match a broadcast domain ("ethernet") or in the case of
IP addresses that are treated as routed or NAT'd /32s, there would (which can
confusing) a netblock record for the the /32 "network" and a singlea ddress
member for the deployed IP address.   Thia means that the mask of every single
address typically matches mask of it's parent block.

Validation determines if this is enforced.

h2. Netblock Types

The netblock type allows different rules to be applied to different netblock
types and to some extent acts like a diffent table for each type.

Netblock types can enforce hierarchy and uniquness by adjusting masks, and
can also just ensure that data inserted matches those qualities (or raises
an exception).

Most of the database uses type "default."   This has encrocement/mangement
turned on and ensures IP address uniqueness and that there's a hierarchy
for everything.  To that end, it is not possible to insert a single address
of this type without having a parent network in it (dangling single address).

When inserting an IP, the databsae will figure out the correct mask, and change
it, regardless of what's inserted, and when changing the mask of a network,
will make sure that all the children networks are changed as well and raise an
exception when a child is outside those boundaries.

There are two other relevant concepts, ip_universes and ip_namespaces.

h2. IP Universes

IP Universes are essentially a grouping of IP addresses that can esee each other
directly.  Many places, there's a default type 0, which is generally meant to
be "the internet' or a location that doesn't bother doing ip universes can just
use that for all IPs.

There's a table, `ip_universe_visibilty` which indicates which universe can see
which other universe.  For example, if there is a site that's in rfc1918 space,
that might exist in one universe (say, named after the site, but there's no
enforcement).  If that site was assiend 192.168.22/20, that would be put in the
unviverse and that universe would be made to see the ineternet, but the internet
could not see the IP universe.

This is mostly interesting with generating DNS.

h3. Namespaces

IP Universes must be unique across a namespace, and there's a default namespace
of "0", regardless of visibility.  This will allow IP space to be managed in
such a way that it's globally unique, even if not globally visible, which is
useful for people's sanity.

In some cases, it may make sense to use the same IP addresses in multiple
locations, such as if there's a cookie cutter approch to locations where every
location looks the same.  In that case, the ip addresses would be in different
universes, and those universes would have different namespaces.    In this
case the database will allow non-unique ip addresses that are the same type.

h3. Cross Universe Connectivity

Here, talk about service endpoings and NATIng.

h2. Overlapping Ranges

In some cases, such as when a site is behind a NATing firewall, a publicly
routed interface exists on one side of the firewall and on the other side of
the firewall, a smaller version of it, or perhaps routed /32s exist inside.
In that acse, there "outside" interface woud be part of one ip universe, and the
inside block would be part of a different universe with a different namespace.
That inside block may need to be carved up into /32 networks which are then
further carved up into single addresses that are actually allocated.
