#!perl

use Test::More tests => 6;
use Test::Exception;

use strict;
use warnings;

use JSP;

is(JSP->supports("threading"), JSP->does_support_threading, "Checking support 'threading'");
is(JSP->supports("utf8"), JSP->does_support_utf8, "Checking support 'utf8'");
is(JSP->supports("e4x"), JSP->does_support_e4x, "Checking support 'e4x'");
is(JSP->supports("E4X"), JSP->supports("e4X"), "Checking ignoring case");
is(JSP->supports("threading", "utf8", "e4x"),
    JSP->does_support_threading && 
    JSP->does_support_utf8 &&
    JSP->does_support_e4x,
    "Checking support for multiple");

throws_ok {
    JSP->supports("non existent feature");
} qr/I don't know about/;
