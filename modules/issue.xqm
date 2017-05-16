xquery version "3.1";


module namespace issue="http://cwulfman.io/matterhorn/issue";
import module namespace config="http://cwulfman.io/matterhorn/config" at "config.xqm";
declare namespace mods="http://www.loc.gov/mods/v3";
declare namespace mets="http://www.loc.gov/METS/";
declare namespace xlink="http://www.w3.org/1999/xlink";
declare namespace test="http://exist-db.org/xquery/xqsuite";

declare function local:bmtn-identifier($bmtnid as xs:string)
as xs:string
{
    concat('urn:PUL:bluemountain:', $bmtnid)
};

declare function local:format-title($constituent as element())
as xs:string*
{
   let $titleInfo := $constituent/mods:titleInfo[1]
    let $displayTitle := data($titleInfo/mods:title[1])
    let $displayTitle :=
        if ($titleInfo/mods:nonSort) then 
            if (matches($titleInfo/mods:nonSort[1], '&apos; *$')) then
                data($titleInfo/mods:nonSort[1]) || $displayTitle
            else data($titleInfo/mods:nonSort[1]) || " " || $displayTitle
        else $displayTitle
    return $displayTitle
};


declare function issue:thumbnail($mets as node())
as xs:string?
{
    let $protocol := "http://",
        $host := "libimages.princeton.edu",
        $service := "loris",
        $region := "full",
        $size :=   "120,",
        $rotation := "0",
        $quality := "default",
        $format := "png"
    let $base := "bluemountain/astore%2Fperiodicals"
    let $thumbnail-path := data($mets//mets:fileGrp[@USE="Images"]/mets:file[1]/mets:FLocat[@LOCTYPE = 'URL']/@xlink:href)
    let $sub-path := replace(substring-after($thumbnail-path, 'file:///usr/share/BlueMountain/astore/periodicals/'), '/', '%2F')
    let $path := string-join(($base,$sub-path), '%2F')
    let $url :=
        string-join((string-join(($protocol, $host, $service, $path, $region, $size, $rotation, $quality), '/'), $format
                        ),
                    '.')
    return $url
};



declare function issue:issue-object-from-mets($mets as node())
as element()
{
    let $id := data(substring-after($mets//mods:identifier[@type='bmtn'], 'urn:PUL:bluemountain:'))
    let $magid := data(substring-after($mets//mods:relatedItem[@type='host']/@xlink:href, 'urn:PUL:bluemountain:'))
    let $dateIssued := 
        if ($mets//mods:dateIssued[empty(@encoding)]) then
            data($mets//mods:dateIssued[empty(@encoding)][1])
        else data($mets//mods:dateIssued[@keyDate = 'yes'])
        
    let $sortKey := data($mets//mods:dateIssued[@keyDate = 'yes'])
    let $citeTitle := data($mets//mods:mods/mods:titleInfo[1]/mods:title[1])
    let $volume := 
        if ($mets//mods:mods/mods:part[@type='issue']/mods:detail[@type='volume']/mods:number) then
            data($mets//mods:mods/mods:part[@type='issue']/mods:detail[@type='volume']/mods:number)
        else ""
    let $number :=
        if ($mets//mods:mods/mods:part[@type='issue']/mods:detail[@type='number']/mods:number) then
            let $numbers := $mets//mods:mods/mods:part[@type='issue']/mods:detail[@type='number']/mods:number
            return
            if (count($numbers) = 1) then
                data($numbers)
            else string-join($numbers, ',')
        else ""
    
    let $citeNumber := 
        if ($volume and $number) then    
            string-join(($volume,$number), '.')
        else $number
        
    let $thumbnail := issue:thumbnail($mets)
        
    let $constituents :=
        for $constituent in $mets//mods:relatedItem[@type='constituent' and mods:genre = ('TextContent', 'Illustration', 'Music')]
            let $contributors := 
                for $name in distinct-values($constituent//mods:name)
                    return  element { xs:QName('contributor') } {
                        if ($name/@valueURI) then
                            attribute ref { data($name/@valueURI) }
                        else (),
                        attribute displayForm { data($name/mods:displayForm[1]) }
                  }
            let $displayTitle := local:format-title($constituent)
            let $citeStringa:= 
                if ($contributors) then
                    string-join( for $c in $contributors return data($c/@displayForm), ', ') || '. '
                else ()
            
            let $citeStringb :=
                if ($displayTitle) then
                    data($citeStringa) || '&quot;' || data($displayTitle) || '.&quot; '
                else $citeStringa || 'Untitled. '
            
            let $citeString := 
                $citeStringb || data($citeTitle) || ' ' || $dateIssued || '.'
                
        return element { xs:QName('constituent') } { 
            attribute id { string-join(($id, data($constituent/@ID)), '_') },
            attribute issueid { $id },
            attribute magid { $magid },
            if ($constituent/mods:language) then
                attribute lang { data($constituent/mods:language/mods:languageTerm) }
            else (),
            if ($constituent/mods:genre[@type='CCS']) then
                attribute genre { data($constituent/mods:genre[@type='CCS']) }
            else (),
            $contributors,
            element { xs:QName('displayTitle') } { $displayTitle },
            element { xs:QName('citeTitle') } { $citeString }
            }
 
    
    return
        <issue id="{$id}" magid="{$magid}">
            <citeTitle>{ $citeTitle }</citeTitle>
            <citeNumber>{ $citeNumber }</citeNumber>
            <citeDate>{ $dateIssued }</citeDate>
            <sortKey>{ $sortKey }</sortKey>
            <thumbnail>{ $thumbnail }</thumbnail>
            <constituents>{ $constituents }</constituents>
        </issue>
};

declare function issue:issue($bmtnid as xs:string)
as element()
{
    let $mets := collection($config:data-root)//mods:identifier[@type='bmtn' and . = local:bmtn-identifier($bmtnid)]/ancestor::mets:mets
    return issue:issue-object-from-mets($mets)
};