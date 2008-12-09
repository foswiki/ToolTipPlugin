# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2003 Peter Thoeny, peter@thoeny.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html
#
# =========================
#
# This is ToolTip plugin.
#


use strict;
use warnings;
# =========================
package Foswiki::Plugins::ToolTipPlugin;    # change the package name and $pluginName!!!

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName $NO_PREFS_IN_TOPIC
  $DefaultReadersFormat $incToolTip $incBalloon $incCenter $incFollow $debug
);

# This should always be $Rev: 17559 $ so that Foswiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 17559 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '1.5';

$NO_PREFS_IN_TOPIC = 1;

$pluginName = 'ToolTipPlugin';  # Name of this Plugin

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;
    # check for Plugins.pm versions
    if( $Foswiki::Plugins::VERSION < 1 ) {
        Foswiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = Foswiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );

    $DefaultReadersFormat = &Foswiki::Func::getPreferencesValue ("TOOLTIPPLUGIN_READERSFORMAT") || "<li> %READERNAME% : %READERDATE%";

    # Flags to indicate that optional javascript files should be included
    # in the <script tags
    #
    $incToolTip = 0;    # ToolTip present in topic
    $incBalloon = 0;    # Need tip_balloon.js
    $incCenter  = 0;    # Need tip_centerwindow.js
    $incFollow  = 0;    # Need tip_followscroll.js

    # register the _TOOLTIP function to handle %TOOLTIP{...}%
    # This will be called whenever %TOOLTIP% or %TOOLTIP{...}% is
    # seen in the topic text.
    Foswiki::Func::registerTagHandler( 'TOOLTIP', \&_TOOLTIP );

    # Plugin correctly initialized
    Foswiki::Func::writeDebug( "- Foswiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;

    return 1;
} ### sub initPlugin

# The function used to handle the %TOOLTIP{...}% macro
# You would have one of these for each macro you want to process.
sub _TOOLTIP
{
    my ( $session, $params, $theTopic, $theWeb ) = @_;
    my $out = "";

    $incToolTip = 1;    # Tooltip present - need to load JavaScript

    Foswiki::Func::writeDebug(" _TOOLTIP TAG Handler entered ") if $debug;

    if ( ( !$params->{_RAW} ) || ( $params->{_RAW} =~ m/^END$/ ) ) {
        Foswiki::Func::writeDebug(" RETURNING </a> ") if $debug;
      return "</a>";
    }

    $out = "<a border=\"0\" href=\"";
    $out .= $params->{URL} || "javascript:void(0);";
    $out .= "\" ";
    $out .= "target=\"$params->{TARGET}\" " if ( $params->{TARGET} );

    Foswiki::Func::writeDebug(" INPUT   $params->{TEXT} ") if $debug;
    my $text = Foswiki::Func::renderText( $params->{TEXT} );
    Foswiki::Func::writeDebug(" RENDER  $text ") if $debug;

    if ( $params->{INCLUDE} ) {
        Foswiki::Func::writeDebug("topic : $params->{INCLUDE} ") if $debug;
        my $itext   = "%INCLUDE{$params->{INCLUDE}}%";                # Build a standard INCLUDE tag
        my $incText = &Foswiki::Func::expandCommonVariables($itext);    # Expand the include
        $incText = &Foswiki::Func::renderText($incText);                #   and render it.
        $incText =~ s/\n//g;                                          # Remove newlines
        $text = $incText;                                             # Note INCLUDE will superscede the TEXT parameter
    } ### if ( $params->{INCLUDE...

    $text =~ s/([^\\])'/$1\\'/g;                                      # Escape any unescaped single-quotes
    $text =~ s/</&lt;/g;                                              # Escape <
    $text =~ s/>/&gt;/g;                                              # Escape >
    $text =~ s/"/&quot;/g;                                            # Escape double quotes

    $out .= " onmouseover=\"Tip('$text'";

    foreach my $ky ( keys(%$params) ) {                               # Process the parameter array
      next if ( $ky eq "TARGET" );                                    #    Bypassing any parameters
      next if ( $ky eq "URL" );                                       #    That need special processing
      next if ( $ky eq "TEXT" );                                      #    or are not needed.
      next if ( $ky eq "INCLUDE" );
      next if ( $ky eq "_RAW" );

        if ( $ky eq "BALLOON" ) {    # If BALLOON tip without an explicit path, set a default set of images.
            $incBalloon = 1;         # Need to include the Balloon.js file.
            if ( !( $params->{BALLOONIMGPATH} ) ) {
                $out .= ", BALLOONIMGPATH, '$Foswiki::cfg{PubUrlPath}/$Foswiki::cfg{SystemWebName}/$pluginName/balloon/'";
            }
        } ### if ( $ky eq "BALLOON" )

        $incCenter = 1 if $ky =~ /^CENTER.*/;
        $incFollow = 1 if $ky =~ /^FOLLOW.*/;

        if ( $params->{$ky} =~ /^-?\d+$/ ) {    # If signed or unsigned numeric
            $out .= ", " . $ky . ", " . $params->{$ky};    #    append numeric parameters as comma delimited.
        } else {
            $out .= ", " . $ky . ", '" . $params->{$ky} . "'";  #    append text parameters quoted, delimited by comma's
        }

    }    # foreach my $ky

    $out .= ")\" onmouseout=\"UnTip()\"> ";

    Foswiki::Func::writeDebug(" TT NEWOUT = $out ") if $debug;

  return $out;
} ### sub _TOOLTIP

# =========================
sub postRenderingHandler
{
    my $force = Foswiki::Func::getPreferencesFlag("\U$pluginName\E_JSFORCE") || 0;
    if ( !Foswiki::Func::getPreferencesFlag("\U$pluginName\E_JSBYPASS") || $force ) {
        if ( $incToolTip || $force ) {
            my $sHead =
              "<script type=\"text/javascript\" src=\"$Foswiki::cfg{PubUrlPath}/$Foswiki::cfg{SystemWebName}/$pluginName/";
            my $sTail   = "\"></script>\n";
            my $scripts = $sHead . "wz_tooltip.js" . $sTail;
            $scripts .= $sHead . "tip_centerwindow.js" . $sTail if ( $incCenter  || $force );
            $scripts .= $sHead . "tip_followscroll.js" . $sTail if ( $incFollow  || $force );
            $scripts .= $sHead . "tip_balloon.js" . $sTail      if ( $incBalloon || $force );
            $_[0] =~ s|(</body>)|$scripts$1|;   # prepend scripts to closing body tag. 
        } ### if ( $incToolTip || $force)
    } ### if ( !Foswiki::Func::getPreferencesFlag...
  return;
} ### sub postRenderingHandler

1;

