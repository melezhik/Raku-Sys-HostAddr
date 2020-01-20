use v6;
use Test;

#
# Copyright © 2020 Joelle Maslak
# All Rights Reserved - See License
#

use Sys::HostAddr;

diag "Distro: {$*DISTRO.desc}";

# Checking for presence of "ip" command.
my $ip-command-exists = False;
my $old-path = %*ENV<PATH>;
%*ENV<PATH> = (%*ENV<PATH> // "") ~ ":/sbin:/usr/sbin:/etc:/user/etc";
{
    my $out = qqx{which ip 2>/dev/null};
    $ip-command-exists = ($out ne "");

    CATCH { default { } };
}
%*ENV<PATH> = $old-path;
diag "ip command found: $ip-command-exists";

isa-ok Sys::HostAddr.new, Sys::HostAddr, "Constructor runs";

subtest "public" => sub {
    can-ok Sys::HostAddr.new, 'public', "public method exists";
    if %*ENV<REMOTE_TESTING>:exists {
        ok Sys::HostAddr.new.public ~~ Str:D, "Public IPv4 lookup";
        ok Sys::HostAddr.new(:ipv(6)).public ~~ Str, "Public IPv6 lookup";
    } else {
        skip "Not performing remote tests, set \%\*ENV<REMOTE_TESTING>", 2;
    }
}

subtest "interfaces" => sub {
    ok Sys::HostAddr.new.interfaces ~~ Seq:D, "Interface list";
    if $ip-command-exists {
        ok Sys::HostAddr.new.interfaces.elems ≥ 1, "Interface list includes at least 1 interface";
    } else {
        # No ip command means no interfaces.
        ok Sys::HostAddr.new.interfaces.elems == 0, "Interface list includes at zero interfaces";
    }

}

subtest "addresses" => sub {
    my $ha = Sys::HostAddr.new(filter-link-local => False);
    ok $ha.addresses ~~ Seq:D, "Address list";
    if $ip-command-exists {
        ok $ha.addresses ≥ 1, "At least one address returned";
    } else {
        # No ip command means no addresses
        ok $ha.addresses == 0, "No address returned";
    }
}

subtest "addresses-on-interface" => sub {
    my $ha = Sys::HostAddr.new(filter-link-local => False);
    my @interfaces = $ha.interfaces<>;
    my @addresses = $ha.addresses<>;

    my @if-addrs;
    for @interfaces -> $if {
        @if-addrs.append: $ha.addresses-on-interface($if);
    }

    is @if-addrs.unique.sort, @addresses.unique.sort, "All IPs represented";
}

subtest "guess-ip-for-host" => sub {
    can-ok Sys::HostAddr.new, 'guess-ip-for-host', "guess-ip-for-host method exists";
    if %*ENV<REMOTE_TESTING>:exists {
        my $ha = Sys::HostAddr.new;
        if $ip-command-exists {
            ok $ha.guess-ip-for-host('4.2.2.1').defined, "Check we get a default route";
        } else {
            # No ip command means no routes
            ok ! $ha.guess-ip-for-host('4.2.2.1').defined, "Check we got no route";
        }
    } else {
        skip "Not performing remote tests, set \%\*ENV<REMOTE_TESTING>", 1;
    }
}

is %*ENV<PATH>, $old-path, "Path wasn't reset";

done-testing;

