%%%------------------------------------------------------------------
%%% emangosd
%%% Copyright (C) 2011 Hanfei Shen <qqshfox@gmail.com>
%%%
%%% This program is free software; you can redistribute it and/or modify
%%% it under the terms of the GNU General Public License as published by
%%% the Free Software Foundation; either version 2 of the License, or
%%% (at your option) any later version.
%%%
%%% This program is distributed in the hope that it will be useful,
%%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%%% GNU General Public License for more details.
%%%
%%% You should have received a copy of the GNU General Public License
%%% along with this program; if not, write to the Free Software
%%% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
%%%------------------------------------------------------------------

-module(emangosd_srp6a).

-author('Hanfei Shen <qqshfox@gmail.com>').

-export([challenge/1, proof/3]).

-include("records.hrl").

-define(IN, /unsigned-little-integer).
-define(NI, /unsigned-big-integer).
-define(b, /bytes).
-define(QQ, :256).
-define(SH, :160).
-define(DQ, :128).
-define(Q, :64).
-define(L, :32).
-define(W, :16).
-define(B, :8).

challenge(A) ->
	Credentials = crypto:sha(A#account.name ++ ":" ++ A#account.password),
	H = #hash{salt = random:uniform(16#FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
		secret = random:uniform(16#FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)},
	X = sha(<<(H#hash.salt)?QQ?IN, Credentials?b>>),
	Verifier = crypto:mod_exp(H#hash.generator, X, H#hash.modulus),
	Temp = crypto:mod_exp(H#hash.generator, H#hash.secret, H#hash.modulus),
	PublicB = crypto:mod_exp(Verifier * H#hash.multiplier + Temp, 1, H#hash.modulus),
	H#hash{public=PublicB, verifier=Verifier}.

proof(A, H, P) ->
	U = sha(<<A?QQ?IN, (H#hash.public)?QQ?IN>>),
	S1 = crypto:mod_exp(H#hash.verifier, U, H#hash.modulus),
	S2 = crypto:mod_exp(S1 * A, H#hash.secret, H#hash.modulus),
	T0 = <<S2?QQ?IN>>,
	T1 = <<(sha(even(T0)))?SH?NI>>,
	T2 = <<(sha(odd(T0)))?SH?NI>>,
	SK = merge(T1, T2),
	S = sha(<<(H#hash.modulus)?QQ?IN>>),
	X = sha(<<(H#hash.generator)?B>>),
	SX = S bxor X,
	AN = sha(P#account.name),
	CP = sha(<<SX?SH?IN, AN?SH?IN, (H#hash.salt)?QQ?IN, A?QQ?IN, (H#hash.public)?QQ?IN, SK/binary>>),
	SP = sha(<<A?QQ?IN, CP?SH?IN, SK/binary>>),
	H#hash{session_key=SK, client_proof=CP, session_proof=SP}.

sha(Data) ->
	<<Result:160?IN>> = crypto:sha(Data),
	Result.

even(<<X:8,_:8,Z:8>>) -> <<X:8, Z:8>>;
even(<<X:8,_:8>>) -> <<X:8>>;
even(<<_:8>>) -> <<>>;
even(<<X:8,_:8,Z/binary>>) -> <<X:8, (even(Z))/binary>>.

odd(<<_:8,X:8,_:8>>) -> <<X>>;
odd(<<_:8,X:8>>) -> <<X>>;
odd(<<X:8>>) -> <<X>>;
odd(<<_:8,X:8,Z/binary>>) -> <<X:8, (odd(Z))/binary>>.

merge(<<>>, <<>>) -> <<>>;
merge(<<H1:8, T1/binary>>, <<H2:8, T2/binary>>) -> <<(merge(T1, T2))/binary, H1:8, H2:8>>.
