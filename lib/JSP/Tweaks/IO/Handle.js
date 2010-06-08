// Sys.say("Loading tweaks for IO::Handle:"+ this.__PACKAGE__);
({
    'read': new PerlSub(
	'my $buf; my($fd, $len) = @_; read($fd, $buf, $len); $buf'
	)
})
