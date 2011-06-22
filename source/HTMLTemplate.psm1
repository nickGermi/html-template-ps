# HTML::Template::PS
# HTML::Template re-implemented in PowerShell 
# Original by http://sam.tregar.com/, found at http://search.cpan.org/~samtregar/
# ...because I wasn't allowed to use Perl :-(
# Copyright Ian Gibbs 2011 		flash666@yahoo.com
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
	
$version = '0.1'
$error_action = 'stop'                          # What the script should do when any action fails
Function replaceElements($line, $params)
{
        $tags = $true
        while($tags -eq $true)
        {
            $options = [Text.RegularExpressions.RegExOptions]::IgnoreCase
            $tagMatchRegexp = New-Object -TypeName Text.RegularExpressions.Regex -ArgumentList '<TMPL_(VAR|LOOP) NAME="(\w*)">',$options
            $matches = $tagMatchRegexp.Match($line)
            if(!$matches.Success)
            {
                $tags = $false
            }
            else
            {
                $tag = $matches.Groups[0].Value
                $type = $matches.Groups[1].Value
                $name = $matches.Groups[2].Value.ToLower()
                $location = $matches.Index
                $new_text = ""
                #Write-Host "TAG $tag TYPE $type NAME $name"
                if($params.ContainsKey($name))
                {
                    if($type -imatch 'VAR')
                    {
                        $new_text = $params[$name]
                        $tagReplaceRegexp = New-Object -TypeName Text.RegularExpressions.Regex -ArgumentList $tag,$options
                        $line = $tagReplaceRegexp.Replace($line, $new_text, 1)
                    }
                    elseif($type -imatch 'LOOP')
                    {
                        # Find the closing /loop
                        $start_loop = $location + $tag.Length
                        $loopCloseRegexp = New-Object -TypeName Text.RegularExpressions.Regex -ArgumentList "</TMPL_LOOP>",$options
                        $close_loop_matches = $loopCloseRegexp.Match($line, $start_loop)
                        if(!$close_loop_matches.Success)
                        {
                            throw "ERROR: <TMPL_LOOP> without closing </TMPL_LOOP> ($tag)"
                        }
                        $end_loop = $close_loop_matches.Index
                        $end_close_loop = $end_loop + 12
                        $loop_contents = $line.Substring($start_loop, $end_loop - $start_loop)
                        $loop_items = $params[$name]                           # get the loop object
                        foreach($item in $loop_items)
                        {
                            $new_text = $new_text + (replaceElements $loop_contents $item)  # recursively resolve any
                                                                                            # elements inside the loop
                        }
                        $pre_tag = $line.substring(0, $location)
                        $post_tag = $line.substring($end_close_loop, $line.Length - $end_close_loop)
                        $line =  $pre_tag + $new_text + $post_tag
                    }
                    else
                    {
                        throw "ERROR: Unknown tag TMPL_$type"
                    }
                    #Write-Host $line
                }
                else
                {
                    throw "ERROR: Attempt to set non-existant parameter '$name' in template"
                }
            }
        }

        return $line
}

<# 
 .Synopsis
  Uses template files to generate output based on data structures.

 .Description
  A re-implementation of the perl CPAN module HTML::Template. Used to 
  separate form from function. You can generate data structures in PowerShell, 
  write a template file with placeholders for the data, and then call this 
  module to generate the output. Ideal for creating HTML output from PowerShell
  without embedding the HTML into the program, making it easy for others
  to change the look of the output.

 .Parameter Params
  A hashtable of parameters that configure the new object and control the way 
  it behaves. Currently supported are:
		filename		Set to a string that lists the path to the template 
						file to be used to generate output


 .Example
	# Initialise a HTML template object
	$tmpl = New-HTMLTemplate @{ filename = "c:\test.tmpl"; }
	# Add a scalar element (TMPL_VAR)
	$tmpl.param("title","State Report")
	# Add a repeaing element, as might be displayed in a table (TMPL_LOOP)
	$tmpl.param("table", @( @{FRUIT = "apple"}, @{FRUIT = "orange"}, @{FRUIT = "banana"} ))
	# Generate the output
	Write-Output $tmpl.output()
#>
Function New-HTMLTemplate([hashtable]$params)
{
	if(!$params)
	{
		throw "ERROR: no parameters specified"
    }
    if($params["filename"].Length -lt 1)
    {
        throw "ERROR: prequired parameter 'filename' not specified"
    }
    if(!(Test-Path $params["filename"]))
    {
        throw $("ERROR: template file " + $params["filename"] + " does not exist")
    }
    
    $content = (Get-Content $params["filename"] | Out-String)
    
    $template = New-Object -typeName System.Object
    Add-Member -InputObject $template -MemberType NoteProperty -Name filename -Value $params["filename"]
    Add-Member -InputObject $template -MemberType NoteProperty -Name params -Value @{}
    Add-Member -InputObject $template -MemberType NoteProperty -Name template -Value $content
    Add-Member -InputObject $template -MemberType ScriptMethod -Name output -Value {
        return replaceElements $this.template $this.params
    }
    Add-Member -InputObject $template -MemberType ScriptMethod -Name param -Value {
        $key = $args[0].ToLower()
        $value = $args[1]
        $this.params[$key] = $value
    }

    return $template
}
Export-ModuleMember -function New-HTMLTemplate