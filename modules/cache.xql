xquery version "3.1";

declare namespace skos="http://www.w3.org/2004/02/skos/core#";
declare namespace rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#";
declare namespace schema="http://schema.org/";

declare option exist:serialize "method=html5 media-type=text/html omit-xml-declaration=yes indent=yes";

import module namespace console="http://exist-db.org/xquery/console";
import module namespace magazine="http://cwulfman.io/matterhorn/magazine" at "magazine.xqm";

declare function local:cache-magazines() {
let $collection-path := "data/bmtn/cache"
let $magazines := magazine:magazines()
return
    xmldb:store($collection-path, "magazines.xml", $magazines)
};


declare function local:cache-magazine-pages() {
let $collection-path := "data/bmtn/cache"
let $magazines := doc('/db/data/bmtn/cache/magazines.xml')//magazine
let $top := xmldb:store($collection-path, "index.html", local:view())
return
    for $mag in $magazines
    let $path := string-join(($collection-path, data(substring-after($mag/id, 'urn:PUL:bluemountain:'))), '/')
    let $collection :=
        if (xmldb:collection-available($path)) then
            '/db/' || $path
    else xmldb:create-collection('/db', $path)
    return xmldb:store($path, "index.html", local:magazine-page($mag)) 
};


declare function local:cache-issue-pages($mag) {
    let $collection-path := "data/bmtn/cache"
    let $path := string-join(($collection-path, data(substring-after($mag/id, 'urn:PUL:bluemountain:'))), '/')
    for $issue in $mag/issues/issue
    return xmldb:store($path, concat($issue/@id, '.html'), local:issue-page($issue))
};

declare function local:issue-page($issue)
{
    <html>
        <head>
            <title>{ data($issue/citeTitle), (data($issue/citeDate)) }</title>
            <meta charset="utf-8" />
        </head>
        <body>
            <header>
                <h1>{ data($issue/citeTitle) }</h1>
                <p>{ data($issue/citeDate) }</p>
                <img src="{ data($issue/thumbnail) }" alt="thumbnail of issue" />
                <nav>
                    <table>
                    {
                        for $c in $issue/constituents/constituent
                        return
                        if ($c/displayTitle) then
                        <tr>
                            <td>{ data($c/displayTitle) }</td>
                            <td>
                            {
                                if ($c/contributor) then
                                    string-join($c/contributor/@displayForm, ', ')
                                else ""
                            }
                            </td>
                        </tr>
                        else ()
                    }
                    </table>
                </nav>
            </header>
        </body>
    </html>
};

declare function local:magazine-page($mag) as element()
{
    
    let $unauthorized-contributors := $mag//contributor[empty(@ref)]
    let $authorized-contributors := $mag//contributor except $unauthorized-contributors
    
    return
    <html>
        <head>
            <title>{ data($mag/displayTitle) }</title>
            <meta charset="utf-8" />
        </head>
        <body>
            <header>
                <h1>{ data($mag/displayTitle) }</h1>
                <p class="subHead"><span class="dateIssued">{ data($mag/dateIssued) }</span></p>
                <img src="{data($mag/thumbnail)}" alt="thumbnail of magazine" />
                <nav>
                    <ul>
                        <li><a href="#issues">Issues</a></li>
                        <li><a href="#contributors">Contributors</a></li>
                    </ul>
                </nav>
            </header>
            <div id="issues">
            
            </div>
            <div id="contributors">
                <h2>authorized contributors</h2>
                <dl>
                    {
                        for $contributor in $authorized-contributors
                        let $ref := data($contributor/@ref) 
                        let $rdf := local:contributors_rec($ref)
                        group by $ref
                        return
                            (<dt>{ local:contributors_label($rdf) }</dt>,
                            <dd>{ count($contributor) }</dd>)
                    }
                </dl>
                <h2>unauthorized contributors</h2>
                <dl>
                    {
                        for $displayForm in distinct-values($unauthorized-contributors/@displayForm)
                        return
                            (<dt>{ $displayForm }</dt>,
                             <dd>{ count($unauthorized-contributors[@displayForm = $displayForm]) }</dd>)
                    }
                </dl>
            </div>
        </body>
    </html>
};

declare function local:view() as element()
{
    <html>
        <head>
            <title>Magazines</title>
            <meta charset="utf-8" /> 
        </head>
        <body>
            <nav>
                <ul>
                    {
                        for $magazine in doc('/db/data/bmtn/cache/magazines.xml')//magazine
                        order by $magazine/sortKey
                        return
                            <li>
                                <figure>
                                    <img src="{data($magazine/thumbnail)}"/>
                                    <figcaption>

                                        <span class="displayTitle">{ data($magazine/displayTitle) }</span>
                                        <span class="dateIssued">{ data($magazine/dateIssued) }</span>
                                    </figcaption>
                                    <nav><a href="{data($magazine/link)}">more</a></nav>
                                </figure>
                            </li>
                    }
                </ul>
            </nav> 
        </body>
    </html>
};


declare function local:contributors_rec($id as xs:string)
as element()
{
    try {
        collection('/db/data/bmtn/auth/local')/person[@viafURI = $id]
    } catch * {
        error((), "no rec for {$id}")
    }
};

declare function local:contributors_label($contributor)
as xs:string
{
    data($contributor/prefLabel)
};


declare function local:crec($person)
{
    <contributor>
    { $person }
    <contributions>
    {
        for $constituent in doc('/db/data/bmtn/cache/magazines.xml')//constituent[contributor/@ref = $person/@viafURI]
        order by $constituent/@id
        return $constituent
    }
    </contributions>
    </contributor>
};

declare function local:gen-contributors()
{
let $persons :=
    for $contributorRef in distinct-values(doc('/db/data/bmtn/cache/magazines.xml')//contributor/@ref)
    return collection('/db/data/bmtn/auth/local')/person[@viafURI=$contributorRef]
    
return 
    <contributors>
    {
        for $person in $persons
        order by $person/sortLabel
        return
        <contributor>
            { $person }
            {
                for $constituent in 
                  doc('/db/data/bmtn/cache/magazines.xml')
                  //constituent[contributor/@ref = $person/@viafURI]
                order by $constituent/@id
                return $constituent
            }
        </contributor>
    }
    </contributors>
};

let $samplemag := doc('/db/data/bmtn/cache/magazines.xml')//magazine[id = "urn:PUL:bluemountain:bmtnaaf"]


(:return local:magazine-page($samplemag):)
 return local:cache-magazines()
(:return local:cache-magazine-pages():)
(: return local:cache-issue-pages($samplemag) :)
(:return local:gen-contributors():)
    
