/******************************** Query 1 *************************************/

select author.name
from author
inner join writes on author.aid = writes.aid
inner join publication on writes.pid = publication.pid
where publication.title = "Making database systems usable"
order by author.name;

-- +--------------------+
-- | name               |
-- +--------------------+
-- | Aaron Elkiss       |
-- | Adriane P. Chapman |
-- | Arnab Nandi        |
-- | Cong Yu            |
-- | H. V. Jagadish     |
-- | Magesh Jayapandian |
-- | Yunyao Li          |
-- +--------------------+
-- 7 rows in set (1.41 sec)


/******************************** Query 2 *************************************/

select count(distinct aid)
from writes
where pid in (
    select pid
    from publication
    where cid = (
        select cid
        from conference
        where name = "ICDE"
    )
    or jid = (
        select jid
        from journal
        where name = "PVLDB"
    )
);

-- +---------------------+
-- | count(distinct aid) |
-- +---------------------+
-- |                6815 |
-- +---------------------+
-- 1 row in set (0.03 sec)


/******************************** Query 3 *************************************/

select
    a.name as author_name,
    a.homepage as author_homepage,
    o.name as organization_name
from author as a
inner join author as b on a.oid = b.oid
inner join organization as o on a.oid = o.oid
where b.name = "Divesh Srivastava" and a.homepage is not NULL
limit 1;

-- +-------------+-------------------------------------------------------------+--------------------+
-- | author_name | author_homepage                                             | organization_name  |
-- +-------------+-------------------------------------------------------------+--------------------+
-- | Lee Breslau | http://www.research.att.com/people/Breslau_Lee_M/index.html | AT&T Labs Research |
-- +-------------+-------------------------------------------------------------+--------------------+
-- 1 row in set (0.36 sec)


/******************************** Query 4 *************************************/

select
    organization.name as organization_name,
    count(author.aid) as num_authors
from organization
inner join author on organization.oid = author.oid
group by organization_name;

-- 10857 rows in set (5.46 sec)


/******************************** Query 5 *************************************/

select
    publication.year,
    count(publication.pid) as num_publications
from publication
inner join conference on publication.cid = conference.cid
where conference.name = "VLDB" and publication.year between 1995 and 2002
group by publication.year
order by publication.year;

-- +------+------------------+
-- | year | num_publications |
-- +------+------------------+
-- | 1995 |               82 |
-- | 1996 |               84 |
-- | 1997 |               78 |
-- | 1998 |               89 |
-- | 1999 |               82 |
-- | 2000 |              110 |
-- | 2001 |              116 |
-- | 2002 |              129 |
-- +------+------------------+
-- 8 rows in set (0.01 sec)


/******************************** Query 6 *************************************/

select
    title,
    year,
    citation_num
from publication
where pid in (
    select pid
    from publication_keyword
    where kid = (
        select kid
        from keyword
        where keyword = "Natural Language"
    )
)
order by citation_num desc limit 10;

-- +------------------------------------------------------------------------------------------+------+--------------+
-- | title                                                                                    | year | citation_num |
-- +------------------------------------------------------------------------------------------+------+--------------+
-- | Conditional Random Fields: Probabilistic Models for Segmenting andLabeling Sequence Data | 2001 |         2436 |
-- | WordNet: a lexical database for English                                                  | 1995 |         1449 |
-- | The Generative Lexicon                                                                   | 1991 |         1112 |
-- | Semantics of Context-Free Languages                                                      | 1968 |         1032 |
-- | Fuzzy logic = computing with words                                                       | 1996 |          862 |
-- | A Logic-Based Calculus of Events                                                         | 1985 |          858 |
-- | An efficient context-free parsing algorithm                                              | 1970 |          851 |
-- | Inductive learning algorithms and representations for text categorization                | 1998 |          727 |
-- | Class-based n-gram models of natural language                                            | 1992 |          656 |
-- | A computational approach to fuzzy quantifiers in natural languages                       | 1983 |          651 |
-- +------------------------------------------------------------------------------------------+------+--------------+
-- 10 rows in set (2.52 sec)


/******************************** Query 7 *************************************/

select
    author.name as auth_name,
    organization.name as org_name
from author
inner join organization on author.oid = organization.oid
where author.aid in (
    select c.aid
    from writes as a
    -- same papers
    inner join writes as b on a.pid = b.pid
    inner join writes as c on b.pid = c.pid
    -- coauthor 1
    where a.aid = (
        select aid
        from author
        where name = "H. V. Jagadish"
    -- coauthor 2
    ) and b.aid = (
        select aid
        from author
        where name = "Divesh Srivastava"
    -- different from 1 and 2
    ) and c.aid != a.aid and c.aid != b.aid
);

-- 31 rows in set (1.16 sec)


/******************************** Query 8 *************************************/

with num_collab_with_jag as (
    select
        a.aid,
        count(a.pid) as num_collab
    from writes as a
    inner join writes as b on a.pid = b.pid
    where a.aid != b.aid and b.aid = (
        select aid
        from author
        where name = "H. V. Jagadish"
    )
    group by a.aid
),

num_collab_with_div as (
    select
        a.aid,
        count(a.pid) as num_collab
    from writes as a
    inner join writes as b on a.pid = b.pid
    where a.aid != b.aid and b.aid = (
        select aid
        from author
        where name = "Divesh Srivastava"
    )
    group by a.aid
),

ans_aid as (
    select num_collab_with_jag.aid
    from num_collab_with_jag
    left outer join num_collab_with_div on num_collab_with_jag.aid = num_collab_with_div.aid
    where
        num_collab_with_div.num_collab is NULL
        or num_collab_with_jag.num_collab > num_collab_with_div.num_collab
)

select author.name
from author
inner join ans_aid on author.aid = ans_aid.aid;

-- 209 rows in set (0.69 sec)


/******************************** Query 9 *************************************/

-- Is your query too slow?
-- https://dist.neo4j.com/wp-content/uploads/20160223191758/index-all-the-things-meme.jpg
create index cited on cite (cited);
-- probably need to lock the table?

with ans as (
    select
        title,
        citation_num
    from publication
    where pid in (
        select citing
        from cite
        where cited in (
            -- papers by div
            select writes.pid
            from author
            inner join writes on author.aid = writes.aid
            where author.name = "Divesh Srivastava"
        )
    )
)

-- we could do: `order by citation_num desc limit 1, 1`,
-- but it doesn't work for more than one second largest.
select
    title,
    citation_num
from ans
where citation_num = (
    -- find second largest
    select distinct citation_num from ans
    order by citation_num desc limit 1, 1
);

-- +------------------------------------------+--------------+
-- | title                                    | citation_num |
-- +------------------------------------------+--------------+
-- | Models and issues in data stream systems |         1125 |
-- +------------------------------------------+--------------+
-- 1 row in set (2.79 sec)


/******************************** Query 10 ************************************/

select author.name
from author
inner join organization on author.oid = organization.oid
where
    organization.name = "University of California Berkeley"
    and author.aid in (
        select aid
        from domain_author
        where did in (
            select did
            from domain
            where name = "Data Mining" or name = "Artificial Intelligence"
        )
    );

-- 443 rows in set (2.36 sec)


/******************************** Query 11 ************************************/

with ans_aid as (
    select w.aid
    from writes as w
    inner join writes as v on w.pid = v.pid
    where
        -- authors who have written a paper citing the given title
        w.aid in (
            select aid
            from writes
            where pid in (
                select citing
                from cite
                where cited = (
                    select pid
                    from publication
                    where title = "Efficient similarity search in sequence databases"
                )
            )
        )
        -- Jag himself
        and v.aid = (
            select aid
            from author
            where name = "H. V. Jagadish"
        )
        -- no self collab
        and w.aid != v.aid
    group by w.aid
    order by count(w.pid) desc limit 10
)

select author.name
from author
inner join ans_aid on author.aid = ans_aid.aid;

-- +---------------------+
-- | name                |
-- +---------------------+
-- | Rakesh Agrawal      |
-- | Nick Koudas         |
-- | Jignesh M. Patel    |
-- | Christos Faloutsos  |
-- | Beng Chin Ooi       |
-- | Raymond Ng          |
-- | S Muthukrishnan     |
-- | Kenneth Clem Sevcik |
-- | Alexandros Biliris  |
-- | Alberto Mendelzon   |
-- +---------------------+
-- 10 rows in set (2.22 sec)


/******************************** Query 12 ************************************/

with rdb_papers as (
    select pid
    from publication_keyword
    where kid = (
        select kid
        from keyword
        where keyword = "Relational Database"
    )
)

select conference.name
from conference
inner join publication on conference.cid = publication.cid
inner join rdb_papers on publication.pid = rdb_papers.pid
group by conference.name
having count(conference.name) > 50

union all

select journal.name
from journal
inner join publication on journal.jid = publication.jid
inner join rdb_papers on publication.pid = rdb_papers.pid
group by journal.name
having count(journal.name) > 50;

-- +--------------------+
-- | name               |
-- +--------------------+
-- | VLDB               |
-- | ICDE               |
-- | PODS               |
-- | ER(OOER)           |
-- | SIGMOD             |
-- | DEXA               |
-- | TODS               |
-- | Sigmod Record      |
-- | DKE                |
-- | TKDE               |
-- | CORR               |
-- | IS                 |
-- | BMC Bioinformatics |
-- +--------------------+
-- 13 rows in set (5.46 sec)
