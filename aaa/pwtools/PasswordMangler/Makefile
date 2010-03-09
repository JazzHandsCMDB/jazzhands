
# Copyright (c) 2005-2010, Vonage Holdings Corp.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY VONAGE HOLDINGS CORP. ''AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL VONAGE HOLDINGS CORP. BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

CPPDEBUG=/ZI /D DEBUG /D _CONSOLE
#CPPDEBUG=/D NDEBUG /Zd /O2
LDDEBUG=/DEBUG /SUBSYSTEM:CONSOLE
#LDDEBUG=/SUBSYSTEM:CONSOLE

#
# CFLAGS explanation
#  /W3   - warning level 3
#  /Wp64 - warn if not 64-bit clean
#  /WX   - treat warnings as errors
#  /MD   - multi-threaded DLL
#  /EHsc - enable C++ exceptions
#  /TP   - source file is C++
#
LINK=link
#CPPFLAGS=/nologo /W3 /Wp64 /WX /D WIN32 /MD /EHsc /TP /errorReport:none $(CPPDEBUG) /D _UNICODE
CPPFLAGS=/nologo /W3 /Wp64 /WX /D WIN32 /MD /EHsc /TP /errorReport:none $(CPPDEBUG) /D _UNICODE /D UNICODE
LDFLAGS=/NOLOGO /MACHINE:X86 /errorReport:none $(LDDEBUG)
WINLIBS=kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib
PMLIBS=strsafe.lib adsiid.lib activeds.lib wininet.lib $(WINLIBS)

all: PasswordMangler

.SUFFIXES : .h .mc .rc .dll .res

.mc.h:
	mc $<

.mc.rc:
	mc $<

.rc.RES:
	rc $<

PasswordMangler: PasswordMangler.dll JazzHandsmsgcat.dll

PasswordMangler.lib: PasswordMangler.dll

PasswordMangler.dll: PasswordMangler.obj PasswordMangler.def
	$(LINK) $(LDFLAGS) /DLL /OUT:$*.dll /DEF:$*.def $*.obj $(PMLIBS)

PasswordMangler.obj: JazzHandsmsgcat.h

JazzHandsmsgcat.dll: JazzHandsmsgcat.RES
	$(LINK) $(LDFLAGS) /DLL /NOENTRY /OUT:$*.dll $*.RES

JazzHandsmsgcat.rc: JazzHandsmsgcat.mc

JazzHandsmsgcat.RES: JazzHandsmsgcat.mc

JazzHandsmsgcat.h: JazzHandsmsgcat.mc

test.exe: PasswordMangler.lib test.obj
	$(LINK) $(LDFLAGS) /OUT:$*.exe $*.obj $(WINLIBS) PasswordMangler.lib

clean:
	@del MSG*.bin
	@del JazzHandsmsgcat.h JazzHandsmsgcat.rc
	@del *.obj *.dll *.ilk *.idb *.manifest *.exp *.pdb *.lib *.res *.suo
	@del test.exe
