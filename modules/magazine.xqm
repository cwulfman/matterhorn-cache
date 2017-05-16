xquery version "3.1";

module namespace magazine="http://cwulfman.io/matterhorn/magazine";
import module namespace templates="http://exist-db.org/xquery/templates" ;
import module namespace config="http://cwulfman.io/matterhorn/config" at "config.xqm";
import module namespace issue="http://cwulfman.io/matterhorn/issue" at "issue.xqm";
declare namespace mods="http://www.loc.gov/mods/v3";
declare namespace mets="http://www.loc.gov/METS/";
declare namespace xlink="http://www.w3.org/1999/xlink";
declare namespace test="http://exist-db.org/xquery/xqsuite";

(: Dummy test; not using test module yet, though. :)
declare
    %test:assertEquals("Hello world")
function local:hello() {
    "Hello world"
};


(: Compiles data about the overall dataset :)
declare function magazine:magazines()
as element()+
{
    let $mags :=
        for $mets in collection($config:data-root)//mods:genre[@authority="bmtn" and . = "Periodicals-Title"]/ancestor::mets:mets
        return local:magazine-object-from-mets($mets)
    return 
        <magazines count="{count($mags)}">
        { for $mag in $mags return $mag }
        </magazines>
};

declare function local:bmtn-identifier($bmtnid as xs:string)
as xs:string
{
    concat('urn:PUL:bluemountain:', $bmtnid)
};

declare function local:magazine($bmtnid as xs:string)
as element()
{
    collection($config:data-root)//mods:identifier[@type='bmtn' and . = local:bmtn-identifier($bmtnid)]
};

declare function magazine:magazine($bmtnid as xs:string)
as element()
{
    local:magazine-object-from-mets(local:magazine($bmtnid))
};

declare function magazine:thumbnail($mets as node())
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
    let $thumbnail-path := data($mets//mets:file[@ID = 'title_thumbnail']/mets:FLocat[@LOCTYPE = 'URL']/@xlink:href)
    let $sub-path := replace(substring-after($thumbnail-path, 'file:///usr/share/BlueMountain/astore/periodicals/'), '/', '%2F')
    let $path := string-join(($base,$sub-path), '%2F')
    let $url :=
        string-join((string-join(($protocol, $host, $service, $path, $region, $size, $rotation, $quality), '/'), $format
                        ),
                    '.')
    return $url
};


declare function local:magazine-object-from-mets($mets as node())
as element()
{
    let $id := data($mets//mods:identifier[@type="bmtn"])
    let $titleInfo := $mets//mods:titleInfo[@usage="primary"]
    let $displayTitle := data($titleInfo/mods:title)
    let $displayTitle :=
        if ($titleInfo/mods:nonSort) then 
            if (matches($titleInfo/mods:nonSort, '&apos; *$')) then
                data($titleInfo/mods:nonSort) || $displayTitle
            else data($titleInfo/mods:nonSort) || " " || $displayTitle
        else $displayTitle
    let $dateString := data($mets//mods:mods/mods:originInfo/mods:dateIssued[empty(@point)])
    let $thumbnail := magazine:thumbnail($mets)
    let $issues := 
        for $issue in collection($config:data-root)//mods:relatedItem[@type='host' and @xlink:href=$id]/ancestor::mets:mets
        return issue:issue-object-from-mets($issue)

    let $contributors :=
        for $contributor in $issues//contributor
        let $label :=
            if ($contributor/@ref) then
                data(collection('/db/data/bmtn/auth/local')//person[@viafURI=$contributor/@ref]/prefLabel)
            else data($contributor/@displayForm)
        let $id :=
            if ($contributor/@ref) then
                data(collection('/db/data/bmtn/auth/local')//person[@viafURI=$contributor/@ref]/@id)
            else ()
            
        let $sort :=
            if ($contributor/@ref) then 
                data(collection('/db/data/bmtn/auth/local')//person[@viafURI=$contributor/@ref]/sortLabel)
            else data($contributor/@displayForm)
        group by $label
        order by count($contributor) descending
        return 
            <contributor label="{$label}" sort="{$sort[1]}" count="{count($contributor)}" >
                { if (count($id) > 0) then attribute id { $id[1] } else () }
            </contributor>
        
    

    return
        <magazine>
            <id>{ substring-after($id, 'urn:PUL:bluemountain:') }</id>
            <link>{substring-after($id, 'urn:PUL:bluemountain:') || '/index.html'}</link>
            <displayTitle>{ $displayTitle }</displayTitle>
            <sortKey>{ lower-case(normalize-space($titleInfo/mods:title)) }</sortKey>
            <dateIssued>{ $dateString }</dateIssued>
            <thumbnail>{ $thumbnail }</thumbnail>
            <abstract>{ data($mets//mods:abstract) }</abstract>
            <contributors>{ $contributors }</contributors>
            <issues count="{ count($issues) }">{ $issues }</issues>
        </magazine>
};


