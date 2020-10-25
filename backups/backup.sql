--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.18
-- Dumped by pg_dump version 9.6.18

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: btree_gist; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;


--
-- Name: EXTENSION btree_gist; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION btree_gist IS 'support for indexing common datatypes in GiST';


--
-- Name: pg_stat_statements; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA public;


--
-- Name: EXTENSION pg_stat_statements; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_stat_statements IS 'track execution statistics of all SQL statements executed';


--
-- Name: get_prohibited_creatives_for_events(integer[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_prohibited_creatives_for_events(VARIADIC event_ids integer[]) RETURNS TABLE(event_id integer, event_audience_id integer, event_treatment_set_id integer, creative_id integer, prohibited_creative_ids integer[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    creative_ids integer[];
BEGIN
    creative_ids := ARRAY(
        SELECT ec.creative_id
        FROM content_library_eligiblecreative ec
        INNER JOIN content_library_eventaudiencecontentblock eacb
            ON ec.event_audience_contentblock_id = eacb.id
        INNER JOIN content_library_eventaudience ea
            ON eacb.event_audience_id = ea.id
        WHERE (
            ea.event_id = ANY(event_ids)
            AND
            eacb."mode" = 1 -- where EACB is Forced
            AND
            ec.included = true
        )
    );
    
    RETURN QUERY
    WITH prohibited_creatives AS (
        SELECT 
            * 
        FROM
            prohibited_creatives_view 
        WHERE 
            prohibited_creatives_view.creative_id = ANY(creative_ids)
    )
    SELECT
        ea.event_id,
        eacb.event_audience_id,
        eacb.event_treatment_set_id,
        ec.creative_id,
        ARRAY_AGG(pc.prohibited_creative_id) as prohibited_creative_ids
    FROM
        content_library_eventaudiencecontentblock eacb
        LEFT JOIN content_library_eventaudience ea
            ON eacb.event_audience_id = ea.id
        LEFT JOIN content_library_eligiblecreative ec 
            ON eacb.id = ec.event_audience_contentblock_id
        INNER JOIN prohibited_creatives pc 
            ON ec.creative_id = pc.creative_id
        WHERE (
            ea.event_id = ANY(event_ids)
            AND
            eacb."mode" = 1 -- where EACB is Forced
            AND
            ec.included = true
        )
        GROUP BY (
            ea.event_id,
            eacb.event_audience_id,
            eacb.event_treatment_set_id,
            ec.creative_id
        );
END
$$;


--
-- Name: get_prohibited_creatives_for_events_new(integer[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_prohibited_creatives_for_events_new(VARIADIC event_ids integer[]) RETURNS TABLE(event_id integer, event_audience_id integer, creatives_variant_id integer, creative_id integer, prohibited_creative_ids integer[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    creative_ids integer[];
BEGIN
    creative_ids := ARRAY(
        SELECT
            nec.creative_id
        FROM 
            content_library_neweligiblecreative nec
        INNER JOIN 
            content_library_dynamicsectionvariant dsv 
            ON nec.section_variant_id = dsv.id
        INNER JOIN 
            content_library_section s
            ON dsv.section_id = s.id
        WHERE (
            s.event_id = ANY(event_ids)
            AND
            dsv.is_forced = true
            AND
            nec.included = true
        )
    );

    RETURN QUERY
    WITH prohibited_creatives AS (
        SELECT
            *
        FROM 
            prohibited_creatives_view pcv
        WHERE 
            pcv.creative_id = ANY(creative_ids)
    )
    SELECT 
        s.event_id,
        dsv.event_audience_id,
        dsv.creatives_variant_id,
        nec.creative_id,
        ARRAY_AGG(pc.prohibited_creative_id) as prohibited_creative_ids
    FROM
        content_library_dynamicsectionvariant dsv
    INNER JOIN 
        content_library_section s
        ON dsv.section_id = s.id
    INNER JOIN 
        content_library_neweligiblecreative nec
        ON dsv.id = nec.section_variant_id
    INNER JOIN 
        prohibited_creatives pc
        ON nec.creative_id = pc.creative_id
    WHERE (
        s.event_id = ANY(event_ids)
        AND
        dsv.is_forced = true
        AND 
        nec.included = true
    )
    GROUP BY (
        s.event_id,
        dsv.event_audience_id,
        dsv.creatives_variant_id,
        nec.creative_id
    );
END
$$;


--
-- Name: non_null_count(anyarray); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.non_null_count(VARIADIC arg_array anyarray) RETURNS bigint
    LANGUAGE sql IMMUTABLE
    AS $_$
                SELECT COUNT(x) FROM UNNEST($1) AS x
              $_$;


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: account_emailaddress; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.account_emailaddress (
    id integer NOT NULL,
    email character varying(254) NOT NULL,
    verified boolean NOT NULL,
    "primary" boolean NOT NULL,
    user_id integer NOT NULL
);


--
-- Name: account_emailaddress_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.account_emailaddress_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: account_emailaddress_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.account_emailaddress_id_seq OWNED BY public.account_emailaddress.id;


--
-- Name: account_emailconfirmation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.account_emailconfirmation (
    id integer NOT NULL,
    created timestamp with time zone NOT NULL,
    sent timestamp with time zone,
    key character varying(64) NOT NULL,
    email_address_id integer NOT NULL
);


--
-- Name: account_emailconfirmation_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.account_emailconfirmation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: account_emailconfirmation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.account_emailconfirmation_id_seq OWNED BY public.account_emailconfirmation.id;


--
-- Name: auth_group; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_group (
    id integer NOT NULL,
    name character varying(150) NOT NULL
);


--
-- Name: auth_group_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.auth_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: auth_group_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.auth_group_id_seq OWNED BY public.auth_group.id;


--
-- Name: auth_group_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_group_permissions (
    id integer NOT NULL,
    group_id integer NOT NULL,
    permission_id integer NOT NULL
);


--
-- Name: auth_group_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.auth_group_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: auth_group_permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.auth_group_permissions_id_seq OWNED BY public.auth_group_permissions.id;


--
-- Name: auth_permission; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_permission (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    content_type_id integer NOT NULL,
    codename character varying(100) NOT NULL
);


--
-- Name: auth_permission_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.auth_permission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: auth_permission_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.auth_permission_id_seq OWNED BY public.auth_permission.id;


--
-- Name: content_library_acousticcampaign; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_acousticcampaign (
    emailserviceprovider_ptr_id integer NOT NULL,
    pod integer NOT NULL,
    list_id character varying(255) NOT NULL,
    link_metadata_requires_link_type boolean NOT NULL,
    link_metadata_requires_name boolean NOT NULL,
    relational_table_id character varying(255) NOT NULL,
    query_folder_id character varying(255) NOT NULL,
    default_visibility character varying(10) NOT NULL,
    mailing_parent_folder_path character varying(255) NOT NULL,
    mailing_template_folder_path character varying(255) NOT NULL,
    use_custom_view_in_browser_link boolean NOT NULL,
    CONSTRAINT content_library_acousticcampaign_pod_check CHECK ((pod >= 0))
);


--
-- Name: content_library_acousticcampaigndynamiccontent; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_acousticcampaigndynamiccontent (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    ruleset_name character varying(255) NOT NULL,
    ruleset_id character varying(255) NOT NULL,
    "position" integer NOT NULL,
    created_by_id integer,
    section_id integer NOT NULL,
    updated_by_id integer,
    CONSTRAINT content_library_acousticcampaigndynamiccontent_position_check CHECK (("position" >= 0))
);


--
-- Name: content_library_acousticcampaigndynamiccontent_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_acousticcampaigndynamiccontent_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_acousticcampaigndynamiccontent_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_acousticcampaigndynamiccontent_id_seq OWNED BY public.content_library_acousticcampaigndynamiccontent.id;


--
-- Name: content_library_acousticcampaignfromaddress; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_acousticcampaignfromaddress (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    from_address character varying(254) NOT NULL,
    "default" boolean NOT NULL,
    client_id integer NOT NULL,
    created_by_id integer,
    updated_by_id integer
);


--
-- Name: content_library_acousticcampaignfromaddress_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_acousticcampaignfromaddress_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_acousticcampaignfromaddress_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_acousticcampaignfromaddress_id_seq OWNED BY public.content_library_acousticcampaignfromaddress.id;


--
-- Name: content_library_acousticcampaignfromname; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_acousticcampaignfromname (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    from_name character varying(255) NOT NULL,
    "default" boolean NOT NULL,
    client_id integer NOT NULL,
    created_by_id integer,
    updated_by_id integer
);


--
-- Name: content_library_acousticcampaignfromname_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_acousticcampaignfromname_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_acousticcampaignfromname_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_acousticcampaignfromname_id_seq OWNED BY public.content_library_acousticcampaignfromname.id;


--
-- Name: content_library_acousticcampaignlinkmetadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_acousticcampaignlinkmetadata (
    id integer NOT NULL,
    name character varying(200) NOT NULL,
    acoustic_campaign_id integer NOT NULL,
    link_id integer NOT NULL,
    link_type character varying(20) NOT NULL
);


--
-- Name: content_library_acousticcampaignlinkmetadata_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_acousticcampaignlinkmetadata_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_acousticcampaignlinkmetadata_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_acousticcampaignlinkmetadata_id_seq OWNED BY public.content_library_acousticcampaignlinkmetadata.id;


--
-- Name: content_library_acousticcampaignmailing; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_acousticcampaignmailing (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    mailing_id character varying(255) NOT NULL,
    send_datetime timestamp with time zone,
    created_by_id integer,
    event_id integer NOT NULL,
    updated_by_id integer
);


--
-- Name: content_library_acousticcampaignmailing_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_acousticcampaignmailing_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_acousticcampaignmailing_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_acousticcampaignmailing_id_seq OWNED BY public.content_library_acousticcampaignmailing.id;


--
-- Name: content_library_acousticcampaignreplyto; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_acousticcampaignreplyto (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    reply_to character varying(254) NOT NULL,
    "default" boolean NOT NULL,
    client_id integer NOT NULL,
    created_by_id integer,
    updated_by_id integer
);


--
-- Name: content_library_acousticcampaignreplyto_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_acousticcampaignreplyto_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_acousticcampaignreplyto_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_acousticcampaignreplyto_id_seq OWNED BY public.content_library_acousticcampaignreplyto.id;


--
-- Name: content_library_adhocexperiment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_adhocexperiment (
    baseexperiment_ptr_id integer NOT NULL
);


--
-- Name: content_library_adhoctreatment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_adhoctreatment (
    basetreatment_ptr_id integer NOT NULL,
    "order" smallint NOT NULL,
    experiment_id integer NOT NULL
);


--
-- Name: content_library_adhocvariant; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_adhocvariant (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    created_by_id integer,
    event_id integer NOT NULL,
    updated_by_id integer
);


--
-- Name: content_library_adhocvariant_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_adhocvariant_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_adhocvariant_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_adhocvariant_id_seq OWNED BY public.content_library_adhocvariant.id;


--
-- Name: content_library_adhocvariant_treatments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_adhocvariant_treatments (
    id integer NOT NULL,
    adhocvariant_id integer NOT NULL,
    adhoctreatment_id integer NOT NULL
);


--
-- Name: content_library_adhocvariant_treatments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_adhocvariant_treatments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_adhocvariant_treatments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_adhocvariant_treatments_id_seq OWNED BY public.content_library_adhocvariant_treatments.id;


--
-- Name: content_library_adobecampaigneventmetadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_adobecampaigneventmetadata (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    delivery_id character varying(255) NOT NULL,
    created_by_id integer,
    event_id integer NOT NULL,
    updated_by_id integer
);


--
-- Name: content_library_adobecampaigneventmetadata_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_adobecampaigneventmetadata_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_adobecampaigneventmetadata_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_adobecampaigneventmetadata_id_seq OWNED BY public.content_library_adobecampaigneventmetadata.id;


--
-- Name: content_library_application; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_application (
    id bigint NOT NULL,
    client_id character varying(100) NOT NULL,
    redirect_uris text NOT NULL,
    client_type character varying(32) NOT NULL,
    authorization_grant_type character varying(32) NOT NULL,
    name character varying(255) NOT NULL,
    skip_authorization boolean NOT NULL,
    created timestamp with time zone NOT NULL,
    updated timestamp with time zone NOT NULL,
    client_secret bytea NOT NULL,
    cp_client_id integer NOT NULL,
    user_id integer
);


--
-- Name: content_library_application_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_application_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_application_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_application_id_seq OWNED BY public.content_library_application.id;


--
-- Name: content_library_audience; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_audience (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    title character varying(200) NOT NULL,
    querystring character varying(4000),
    client_id integer NOT NULL,
    created_by_id integer,
    updated_by_id integer,
    archived boolean NOT NULL,
    segment_type smallint NOT NULL,
    filenames character varying(200)[] NOT NULL,
    quote character varying(5) NOT NULL,
    separator character varying(5) NOT NULL,
    default_type smallint NOT NULL
);


--
-- Name: content_library_audiencefilter_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_audiencefilter_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_audiencefilter_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_audiencefilter_id_seq OWNED BY public.content_library_audience.id;


--
-- Name: content_library_availability; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_availability (
    id integer NOT NULL,
    start_end_datetime tstzrange NOT NULL,
    creative_id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    created_by_id integer,
    updated_at timestamp with time zone NOT NULL,
    updated_by_id integer
);


--
-- Name: content_library_availability_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_availability_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_availability_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_availability_id_seq OWNED BY public.content_library_availability.id;


--
-- Name: content_library_availableproductcollection; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_availableproductcollection (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    created_by_id integer,
    updated_by_id integer
);


--
-- Name: content_library_availableproductcollection_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_availableproductcollection_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_availableproductcollection_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_availableproductcollection_id_seq OWNED BY public.content_library_availableproductcollection.id;


--
-- Name: content_library_availableproductcollection_product_values; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_availableproductcollection_product_values (
    id integer NOT NULL,
    availableproductcollection_id integer NOT NULL,
    productvalue_id integer NOT NULL
);


--
-- Name: content_library_availableproductcollection_product_value_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_availableproductcollection_product_value_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_availableproductcollection_product_value_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_availableproductcollection_product_value_id_seq OWNED BY public.content_library_availableproductcollection_product_values.id;


--
-- Name: content_library_baseexperiment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_baseexperiment (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    title character varying(200) NOT NULL,
    uuid uuid NOT NULL,
    short_uuid character varying(7) NOT NULL,
    description text NOT NULL,
    start_end_datetime tstzrange NOT NULL,
    internal boolean NOT NULL,
    seed smallint,
    csv_file_pattern character varying(255) NOT NULL,
    status smallint NOT NULL,
    treatment_assignment_method smallint NOT NULL,
    client_id integer NOT NULL,
    created_by_id integer,
    polymorphic_ctype_id integer,
    updated_by_id integer,
    CONSTRAINT content_library_baseexperiment_seed_check CHECK ((seed >= 0))
);


--
-- Name: content_library_baseexperiment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_baseexperiment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_baseexperiment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_baseexperiment_id_seq OWNED BY public.content_library_baseexperiment.id;


--
-- Name: content_library_basetemplate; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_basetemplate (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    title character varying(200) NOT NULL,
    uuid uuid NOT NULL,
    short_uuid character varying(7) NOT NULL,
    archived boolean NOT NULL,
    is_default boolean NOT NULL,
    body_id integer,
    client_id integer NOT NULL,
    created_by_id integer,
    updated_by_id integer
);


--
-- Name: content_library_basetemplate_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_basetemplate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_basetemplate_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_basetemplate_id_seq OWNED BY public.content_library_basetemplate.id;


--
-- Name: content_library_basetreatment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_basetreatment (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    title character varying(200) NOT NULL,
    uuid uuid NOT NULL,
    size double precision,
    control boolean NOT NULL,
    created_by_id integer,
    polymorphic_ctype_id integer,
    updated_by_id integer
);


--
-- Name: content_library_basetreatment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_basetreatment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_basetreatment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_basetreatment_id_seq OWNED BY public.content_library_basetreatment.id;


--
-- Name: content_library_bodytemplate; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_bodytemplate (
    id integer NOT NULL,
    title character varying(200) NOT NULL,
    base_template_id integer NOT NULL,
    body_id integer
);


--
-- Name: content_library_bodytemplate_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_bodytemplate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_bodytemplate_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_bodytemplate_id_seq OWNED BY public.content_library_bodytemplate.id;


--
-- Name: content_library_bodytemplatecontentblock; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_bodytemplatecontentblock (
    id integer NOT NULL,
    "position" integer NOT NULL,
    is_primary boolean NOT NULL,
    body_template_id integer NOT NULL,
    content_block_id integer NOT NULL,
    CONSTRAINT content_library_bodytemplatecontentblock_position_check CHECK (("position" >= 0))
);


--
-- Name: content_library_bodytemplatecontentblock_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_bodytemplatecontentblock_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_bodytemplatecontentblock_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_bodytemplatecontentblock_id_seq OWNED BY public.content_library_bodytemplatecontentblock.id;


--
-- Name: content_library_cheetahdigital; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_cheetahdigital (
    emailserviceprovider_ptr_id integer NOT NULL,
    client_id character varying(255) NOT NULL,
    consumer_key character varying(255) NOT NULL,
    consumer_secret bytea NOT NULL,
    customer_id character varying(255) NOT NULL,
    link_metadata_requires_name boolean NOT NULL
);


--
-- Name: content_library_cheetahdigitalclientconfig; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_cheetahdigitalclientconfig (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    default_from_name character varying(255) NOT NULL,
    default_from_address_id integer NOT NULL,
    created_by_id integer,
    esp_id integer NOT NULL,
    updated_by_id integer,
    base_audience_filter_name character varying(255) NOT NULL,
    base_table_join_name character varying(255),
    external_proofing_group character varying(255),
    audience_table character varying(255),
    subject_line_variants_table character varying(255),
    CONSTRAINT content_library_cheetah_default_from_address_id_c4919d13_check CHECK ((default_from_address_id >= 0))
);


--
-- Name: content_library_cheetahdigitalclientconfig_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_cheetahdigitalclientconfig_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_cheetahdigitalclientconfig_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_cheetahdigitalclientconfig_id_seq OWNED BY public.content_library_cheetahdigitalclientconfig.id;


--
-- Name: content_library_cheetahdigitalcreativecontentblockdocument; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_cheetahdigitalcreativecontentblockdocument (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    ref_id integer NOT NULL,
    display_name character varying(255) NOT NULL,
    content_block_id integer NOT NULL,
    created_by_id integer,
    creative_id integer NOT NULL,
    updated_by_id integer,
    contents_md5 character varying(32) NOT NULL
);


--
-- Name: content_library_cheetahdigitalcreativecontentblockdocume_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_cheetahdigitalcreativecontentblockdocume_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_cheetahdigitalcreativecontentblockdocume_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_cheetahdigitalcreativecontentblockdocume_id_seq OWNED BY public.content_library_cheetahdigitalcreativecontentblockdocument.id;


--
-- Name: content_library_cheetahdigitalcreativediscountofferdocument; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_cheetahdigitalcreativediscountofferdocument (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    created_by_id integer,
    document_id integer NOT NULL,
    promotion_redemption_id integer NOT NULL,
    updated_by_id integer
);


--
-- Name: content_library_cheetahdigitalcreativedocument; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_cheetahdigitalcreativedocument (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    ref_id integer NOT NULL,
    display_name character varying(255) NOT NULL,
    document_type smallint NOT NULL,
    created_by_id integer,
    creative_id integer NOT NULL,
    updated_by_id integer,
    contents_md5 character varying(32) NOT NULL
);


--
-- Name: content_library_cheetahdigitalcreativedocument_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_cheetahdigitalcreativedocument_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_cheetahdigitalcreativedocument_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_cheetahdigitalcreativedocument_id_seq OWNED BY public.content_library_cheetahdigitalcreativedocument.id;


--
-- Name: content_library_cheetahdigitalcreativepromotiondocument_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_cheetahdigitalcreativepromotiondocument_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_cheetahdigitalcreativepromotiondocument_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_cheetahdigitalcreativepromotiondocument_id_seq OWNED BY public.content_library_cheetahdigitalcreativediscountofferdocument.id;


--
-- Name: content_library_cheetahdigitaleventmetadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_cheetahdigitaleventmetadata (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    campaign_id character varying(255) NOT NULL,
    created_by_id integer,
    event_id integer NOT NULL,
    updated_by_id integer,
    campaign_name character varying(255)
);


--
-- Name: content_library_cheetahdigitaleventmetadata_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_cheetahdigitaleventmetadata_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_cheetahdigitaleventmetadata_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_cheetahdigitaleventmetadata_id_seq OWNED BY public.content_library_cheetahdigitaleventmetadata.id;


--
-- Name: content_library_cheetahdigitallinkmetadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_cheetahdigitallinkmetadata (
    id integer NOT NULL,
    name character varying(200) NOT NULL,
    link_id integer NOT NULL,
    cheetah_digital_id integer NOT NULL
);


--
-- Name: content_library_cheetahdigitallinkmetadata_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_cheetahdigitallinkmetadata_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_cheetahdigitallinkmetadata_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_cheetahdigitallinkmetadata_id_seq OWNED BY public.content_library_cheetahdigitallinkmetadata.id;


--
-- Name: content_library_cheetahdigitalstaticcontentblockdocument; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_cheetahdigitalstaticcontentblockdocument (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    ref_id integer NOT NULL,
    display_name character varying(255) NOT NULL,
    contents_md5 character varying(32) NOT NULL,
    content_block_id integer NOT NULL,
    created_by_id integer,
    updated_by_id integer
);


--
-- Name: content_library_cheetahdigitalstaticcontentblockdocument_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_cheetahdigitalstaticcontentblockdocument_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_cheetahdigitalstaticcontentblockdocument_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_cheetahdigitalstaticcontentblockdocument_id_seq OWNED BY public.content_library_cheetahdigitalstaticcontentblockdocument.id;


--
-- Name: content_library_client; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_client (
    id integer NOT NULL,
    is_active boolean NOT NULL,
    display_name character varying(200) NOT NULL,
    name character varying(50) NOT NULL,
    timezone character varying(63) NOT NULL,
    active boolean NOT NULL
);


--
-- Name: content_library_client_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_client_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_client_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_client_id_seq OWNED BY public.content_library_client.id;


--
-- Name: content_library_clientconfiguration; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_clientconfiguration (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    subject_line smallint NOT NULL,
    preview_text smallint NOT NULL,
    preheader_text smallint NOT NULL,
    preheader_url smallint NOT NULL,
    subject_line_prefix smallint NOT NULL,
    subject_line_suffix smallint NOT NULL,
    client_id integer NOT NULL,
    created_by_id integer,
    updated_by_id integer,
    discount_offer smallint NOT NULL,
    disclaimer_wrapper text NOT NULL,
    promotion_card smallint NOT NULL,
    portal_api_key bytea NOT NULL,
    enable_creative_reporting boolean NOT NULL,
    enable_html_download boolean NOT NULL,
    preheader_link smallint NOT NULL,
    logo_square_id integer,
    default_image_upload_type smallint NOT NULL,
    default_content_personalization_model_id integer,
    logo_header_id integer,
    sto_interval interval NOT NULL,
    export_config jsonb NOT NULL,
    recommendations_config jsonb NOT NULL,
    enable_cdn boolean NOT NULL,
    movable_ink_company_id integer,
    cdn_url character varying(500) NOT NULL,
    default_queue_time interval NOT NULL,
    enable_salesforce_import boolean NOT NULL,
    enable_disclaimer_image boolean NOT NULL,
    sync_to_cdn boolean NOT NULL,
    enable_disclaimer_link boolean NOT NULL,
    enable_persado_campaign boolean NOT NULL,
    CONSTRAINT content_library_clientconfiguratio_movable_ink_company_id_check CHECK ((movable_ink_company_id >= 0))
);


--
-- Name: content_library_clientconfiguration_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_clientconfiguration_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_clientconfiguration_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_clientconfiguration_id_seq OWNED BY public.content_library_clientconfiguration.id;


--
-- Name: content_library_clientreuserule; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_clientreuserule (
    id integer NOT NULL,
    client_id integer NOT NULL,
    other_send_delay interval,
    primary_click_delay interval,
    other_click_delay interval,
    other_conversion_delay interval,
    other_max_uses smallint NOT NULL,
    other_open_delay interval,
    primary_conversion_delay interval,
    primary_max_uses smallint NOT NULL,
    primary_open_delay interval,
    primary_send_delay interval,
    created_at timestamp with time zone NOT NULL,
    created_by_id integer,
    updated_at timestamp with time zone NOT NULL,
    updated_by_id integer,
    CONSTRAINT content_library_clientreuserule_other_max_uses_check CHECK ((other_max_uses >= 0)),
    CONSTRAINT content_library_clientreuserule_primary_max_uses_check CHECK ((primary_max_uses >= 0))
);


--
-- Name: content_library_clientreuserule_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_clientreuserule_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_clientreuserule_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_clientreuserule_id_seq OWNED BY public.content_library_clientreuserule.id;


--
-- Name: content_library_clientuser; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_clientuser (
    id integer NOT NULL,
    organization_id integer NOT NULL,
    user_id integer NOT NULL
);


--
-- Name: content_library_clientuser_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_clientuser_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_clientuser_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_clientuser_id_seq OWNED BY public.content_library_clientuser.id;


--
-- Name: content_library_clientuseradmin; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_clientuseradmin (
    id integer NOT NULL,
    organization_id integer NOT NULL,
    organization_user_id integer NOT NULL
);


--
-- Name: content_library_clientuseradmin_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_clientuseradmin_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_clientuseradmin_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_clientuseradmin_id_seq OWNED BY public.content_library_clientuseradmin.id;


--
-- Name: content_library_contentblock; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_contentblock (
    id integer NOT NULL,
    title character varying(200) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    created_by_id integer,
    updated_at timestamp with time zone NOT NULL,
    updated_by_id integer,
    num_positions integer NOT NULL,
    client_id integer NOT NULL,
    short_uuid character varying(7) NOT NULL,
    uuid uuid NOT NULL,
    render_height integer,
    render_width integer,
    slug character varying(30) NOT NULL,
    html_wrapper text NOT NULL,
    type smallint NOT NULL,
    _tracking_parameters jsonb NOT NULL,
    html_bundle_id integer NOT NULL,
    status character varying(40) NOT NULL,
    CONSTRAINT content_library_contentblock_num_positions_4bbab9a0_check CHECK ((num_positions >= 0)),
    CONSTRAINT content_library_contentblock_render_height_check CHECK ((render_height >= 0)),
    CONSTRAINT content_library_contentblock_render_width_check CHECK ((render_width >= 0))
);


--
-- Name: content_library_contentblock_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_contentblock_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_contentblock_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_contentblock_id_seq OWNED BY public.content_library_contentblock.id;


--
-- Name: content_library_contentblockcreativeversion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_contentblockcreativeversion (
    id integer NOT NULL,
    contents_md5 character varying(32) NOT NULL,
    "timestamp" timestamp with time zone NOT NULL,
    content_block_id integer NOT NULL,
    creative_id integer NOT NULL
);


--
-- Name: content_library_contentblockcreativeversion_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_contentblockcreativeversion_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_contentblockcreativeversion_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_contentblockcreativeversion_id_seq OWNED BY public.content_library_contentblockcreativeversion.id;


--
-- Name: content_library_contentblocktemplatetag; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_contentblocktemplatetag (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    content_block_id integer NOT NULL,
    created_by_id integer,
    template_tag_id integer NOT NULL,
    updated_by_id integer,
    constraint_type smallint NOT NULL
);


--
-- Name: content_library_contentblocktemplatetag_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_contentblocktemplatetag_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_contentblocktemplatetag_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_contentblocktemplatetag_id_seq OWNED BY public.content_library_contentblocktemplatetag.id;


--
-- Name: content_library_contentpersonalizationmodel; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_contentpersonalizationmodel (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    major integer NOT NULL,
    minor integer NOT NULL,
    "default" boolean NOT NULL,
    created_by_id integer,
    updated_by_id integer,
    CONSTRAINT content_library_recommendationsversion_major_check CHECK ((major >= 0)),
    CONSTRAINT content_library_recommendationsversion_minor_check CHECK ((minor >= 0))
);


--
-- Name: content_library_contentpersonalizationmodelexperiment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_contentpersonalizationmodelexperiment (
    baseexperiment_ptr_id integer NOT NULL
);


--
-- Name: content_library_contentpersonalizationmodeltreatment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_contentpersonalizationmodeltreatment (
    basetreatment_ptr_id integer NOT NULL,
    "order" smallint NOT NULL,
    content_personalization_model_id integer,
    experiment_id integer NOT NULL
);


--
-- Name: content_library_contentpersonalizationmodelvariant; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_contentpersonalizationmodelvariant (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    created_by_id integer,
    event_id integer NOT NULL,
    model_id integer NOT NULL,
    treatment_id integer,
    updated_by_id integer
);


--
-- Name: content_library_contentpersonalizationmodelvariant_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_contentpersonalizationmodelvariant_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_contentpersonalizationmodelvariant_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_contentpersonalizationmodelvariant_id_seq OWNED BY public.content_library_contentpersonalizationmodelvariant.id;


--
-- Name: content_library_creative; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_creative (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    title character varying(200) NOT NULL,
    uuid uuid NOT NULL,
    short_uuid character varying(7) NOT NULL,
    status smallint NOT NULL,
    client_id integer NOT NULL,
    created_by_id integer,
    updated_by_id integer,
    audience_id integer,
    preheader_text character varying(255) NOT NULL,
    preheader_url character varying(2000) NOT NULL,
    preview_text character varying(255) NOT NULL,
    subject_line_prefix character varying(255) NOT NULL,
    subject_line_suffix character varying(255) NOT NULL,
    disclaimer character varying(10000) NOT NULL,
    use_preheader_text_as_preview_text boolean NOT NULL,
    slug character varying(30) NOT NULL,
    _attributes jsonb NOT NULL,
    _template_tags jsonb NOT NULL,
    _tracking_parameters jsonb NOT NULL,
    disclaimer_mode smallint NOT NULL,
    disclaimer_symbol text NOT NULL,
    preheader_link_id integer,
    promotion_card_id integer,
    disclaimer_image_id integer,
    disclaimer_link_id integer
);


--
-- Name: content_library_creative_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_creative_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_creative_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_creative_id_seq OWNED BY public.content_library_creative.id;


--
-- Name: content_library_creative_product_collections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_creative_product_collections (
    id integer NOT NULL,
    creative_id integer NOT NULL,
    productcollection_id integer NOT NULL
);


--
-- Name: content_library_creative_product_collections_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_creative_product_collections_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_creative_product_collections_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_creative_product_collections_id_seq OWNED BY public.content_library_creative_product_collections.id;


--
-- Name: content_library_creative_prohibited_creatives; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_creative_prohibited_creatives (
    id integer NOT NULL,
    from_creative_id integer NOT NULL,
    to_creative_id integer NOT NULL
);


--
-- Name: content_library_creative_prohibited_creatives_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_creative_prohibited_creatives_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_creative_prohibited_creatives_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_creative_prohibited_creatives_id_seq OWNED BY public.content_library_creative_prohibited_creatives.id;


--
-- Name: content_library_creative_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_creative_tags (
    id integer NOT NULL,
    creative_id integer NOT NULL,
    tag_id integer NOT NULL
);


--
-- Name: content_library_creative_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_creative_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_creative_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_creative_tags_id_seq OWNED BY public.content_library_creative_tags.id;


--
-- Name: content_library_creativeattribute; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_creativeattribute (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    title character varying(200) NOT NULL,
    uuid uuid NOT NULL,
    "position" integer NOT NULL,
    required boolean NOT NULL,
    slug character varying(30) NOT NULL,
    max_length integer,
    field_type smallint NOT NULL,
    client_id integer NOT NULL,
    created_by_id integer,
    updated_by_id integer,
    default_value character varying(255) NOT NULL,
    format_string character varying(255) NOT NULL,
    display_in_table boolean NOT NULL,
    CONSTRAINT content_library_creativeattribute_position_check CHECK (("position" >= 0))
);


--
-- Name: content_library_creativeattribute_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_creativeattribute_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_creativeattribute_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_creativeattribute_id_seq OWNED BY public.content_library_creativeattribute.id;


--
-- Name: content_library_creativeattributechoice; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_creativeattributechoice (
    id integer NOT NULL,
    title character varying(200) NOT NULL,
    value character varying(200) NOT NULL,
    "position" integer NOT NULL,
    attribute_id integer NOT NULL,
    CONSTRAINT content_library_creativeattributechoice_position_check CHECK (("position" >= 0))
);


--
-- Name: content_library_creativeattributechoice_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_creativeattributechoice_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_creativeattributechoice_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_creativeattributechoice_id_seq OWNED BY public.content_library_creativeattributechoice.id;


--
-- Name: content_library_creativecontentblockdocument; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_creativecontentblockdocument (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    contents_md5 character varying(32) NOT NULL,
    html text NOT NULL,
    content_block_id integer NOT NULL,
    created_by_id integer,
    creative_id integer NOT NULL,
    updated_by_id integer
);


--
-- Name: content_library_creativecontentblockdocument_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_creativecontentblockdocument_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_creativecontentblockdocument_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_creativecontentblockdocument_id_seq OWNED BY public.content_library_creativecontentblockdocument.id;


--
-- Name: content_library_creativepromotion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_creativepromotion (
    id integer NOT NULL,
    stage smallint NOT NULL,
    creative_id integer NOT NULL,
    promotion_id integer NOT NULL
);


--
-- Name: content_library_creativepromotion_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_creativepromotion_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_creativepromotion_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_creativepromotion_id_seq OWNED BY public.content_library_creativepromotion.id;


--
-- Name: content_library_creativereuserule; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_creativereuserule (
    id integer NOT NULL,
    creative_id integer NOT NULL,
    other_click_delay interval,
    other_conversion_delay interval,
    other_max_uses smallint NOT NULL,
    other_open_delay interval,
    other_send_delay interval,
    primary_click_delay interval,
    primary_conversion_delay interval,
    primary_max_uses smallint NOT NULL,
    primary_open_delay interval,
    primary_send_delay interval,
    created_at timestamp with time zone NOT NULL,
    created_by_id integer,
    updated_at timestamp with time zone NOT NULL,
    updated_by_id integer,
    CONSTRAINT content_library_creativereuserule_other_max_uses_check CHECK ((other_max_uses >= 0)),
    CONSTRAINT content_library_creativereuserule_primary_max_uses_check CHECK ((primary_max_uses >= 0))
);


--
-- Name: content_library_creativereuserule_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_creativereuserule_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_creativereuserule_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_creativereuserule_id_seq OWNED BY public.content_library_creativereuserule.id;


--
-- Name: content_library_creativestats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_creativestats (
    id integer NOT NULL,
    report_id character varying(64) NOT NULL,
    creative_id integer NOT NULL
);


--
-- Name: content_library_creativestats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_creativestats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_creativestats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_creativestats_id_seq OWNED BY public.content_library_creativestats.id;


--
-- Name: content_library_discountoffer; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_discountoffer (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    savings_type smallint NOT NULL,
    min_purchase_amount numeric(7,2),
    min_purchase_quantity numeric(2,0),
    amount numeric(9,2),
    fixed_price numeric(7,2),
    percentage numeric(3,0),
    created_by_id integer,
    updated_by_id integer,
    CONSTRAINT content_library_discountoffer_optional_field_provided CHECK ((public.non_null_count(VARIADIC ARRAY[(fixed_price)::text, (amount)::text, (percentage)::text]) = 1))
);


--
-- Name: content_library_discountoffer_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_discountoffer_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_discountoffer_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_discountoffer_id_seq OWNED BY public.content_library_discountoffer.id;


--
-- Name: content_library_document; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_document (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    document_type smallint NOT NULL,
    contents_md5 character varying(32) NOT NULL,
    valid_from timestamp with time zone,
    valid_to timestamp with time zone,
    enable_click_tracking boolean NOT NULL,
    external_reference jsonb NOT NULL,
    email_service_provider smallint NOT NULL,
    content_block_id integer,
    created_by_id integer,
    creative_id integer,
    promotion_redemption_id integer,
    updated_by_id integer
);


--
-- Name: content_library_document_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_document_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_document_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_document_id_seq OWNED BY public.content_library_document.id;


--
-- Name: content_library_dynamicsectionvariant; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_dynamicsectionvariant (
    id integer NOT NULL,
    mode smallint NOT NULL,
    creatives_variant_id integer NOT NULL,
    event_audience_id integer NOT NULL,
    section_id integer NOT NULL,
    is_forced boolean NOT NULL
);


--
-- Name: content_library_dynamicsectionvariant_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_dynamicsectionvariant_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_dynamicsectionvariant_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_dynamicsectionvariant_id_seq OWNED BY public.content_library_dynamicsectionvariant.id;


--
-- Name: content_library_eligiblecreativesexperiment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_eligiblecreativesexperiment (
    baseexperiment_ptr_id integer NOT NULL
);


--
-- Name: content_library_eligiblecreativestreatment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_eligiblecreativestreatment (
    basetreatment_ptr_id integer NOT NULL,
    "order" smallint NOT NULL,
    experiment_id integer NOT NULL
);


--
-- Name: content_library_eligiblecreativesvariant; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_eligiblecreativesvariant (
    id integer NOT NULL,
    event_id integer NOT NULL
);


--
-- Name: content_library_eligiblecreativesvariant_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_eligiblecreativesvariant_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_eligiblecreativesvariant_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_eligiblecreativesvariant_id_seq OWNED BY public.content_library_eligiblecreativesvariant.id;


--
-- Name: content_library_eligiblecreativesvariant_treatments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_eligiblecreativesvariant_treatments (
    id integer NOT NULL,
    eligiblecreativesvariant_id integer NOT NULL,
    eligiblecreativestreatment_id integer NOT NULL
);


--
-- Name: content_library_eligiblecreativesvariant_treatments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_eligiblecreativesvariant_treatments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_eligiblecreativesvariant_treatments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_eligiblecreativesvariant_treatments_id_seq OWNED BY public.content_library_eligiblecreativesvariant_treatments.id;


--
-- Name: content_library_emailserviceprovider; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_emailserviceprovider (
    id integer NOT NULL,
    cp_client_id integer NOT NULL
);


--
-- Name: content_library_emailserviceprovider_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_emailserviceprovider_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_emailserviceprovider_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_emailserviceprovider_id_seq OWNED BY public.content_library_emailserviceprovider.id;


--
-- Name: content_library_event; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_event (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    title character varying(200) NOT NULL,
    uuid uuid NOT NULL,
    short_uuid character varying(7) NOT NULL,
    send_datetime timestamp with time zone,
    client_id integer NOT NULL,
    created_by_id integer,
    template_id integer,
    updated_by_id integer,
    slug character varying(30) NOT NULL,
    _attributes jsonb NOT NULL,
    _tracking_parameters jsonb NOT NULL,
    auto_include_eligible_creatives boolean NOT NULL,
    status character varying(40) NOT NULL,
    send_date date,
    enable_send_tracking boolean NOT NULL,
    base_template_id integer,
    persado_campaign_id integer
);


--
-- Name: content_library_event_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_event_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_event_id_seq OWNED BY public.content_library_event.id;


--
-- Name: content_library_event_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_event_tags (
    id integer NOT NULL,
    event_id integer NOT NULL,
    tag_id integer NOT NULL
);


--
-- Name: content_library_event_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_event_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_event_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_event_tags_id_seq OWNED BY public.content_library_event_tags.id;


--
-- Name: content_library_eventacousticcampaignconfig; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_eventacousticcampaignconfig (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    standard_mailing_template_id character varying(255) NOT NULL,
    created_by_id integer,
    event_id integer NOT NULL,
    from_address_id integer,
    reply_to_id integer,
    updated_by_id integer,
    subject_line_dynamic_content_id character varying(255) NOT NULL,
    visibility character varying(10) NOT NULL,
    from_name_id integer,
    proof_mailing_template_id character varying(255) NOT NULL
);


--
-- Name: content_library_eventacousticcampaignconfig_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_eventacousticcampaignconfig_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_eventacousticcampaignconfig_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_eventacousticcampaignconfig_id_seq OWNED BY public.content_library_eventacousticcampaignconfig.id;


--
-- Name: content_library_eventattribute; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_eventattribute (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    title character varying(200) NOT NULL,
    uuid uuid NOT NULL,
    "position" integer NOT NULL,
    required boolean NOT NULL,
    slug character varying(30) NOT NULL,
    max_length integer,
    field_type smallint NOT NULL,
    client_id integer NOT NULL,
    created_by_id integer,
    updated_by_id integer,
    default_value character varying(255) NOT NULL,
    format_string character varying(255) NOT NULL,
    CONSTRAINT content_library_eventattribute_position_check CHECK (("position" >= 0))
);


--
-- Name: content_library_eventattribute_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_eventattribute_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_eventattribute_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_eventattribute_id_seq OWNED BY public.content_library_eventattribute.id;


--
-- Name: content_library_eventattributecheetahdigitaloptionid; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_eventattributecheetahdigitaloptionid (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    option_id integer NOT NULL,
    created_by_id integer,
    event_attribute_id integer NOT NULL,
    updated_by_id integer,
    field_name character varying(200) NOT NULL,
    CONSTRAINT content_library_eventattributecheetahdigitalopt_option_id_check CHECK ((option_id >= 0))
);


--
-- Name: content_library_eventattributecheetahdigitaloptionid_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_eventattributecheetahdigitaloptionid_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_eventattributecheetahdigitaloptionid_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_eventattributecheetahdigitaloptionid_id_seq OWNED BY public.content_library_eventattributecheetahdigitaloptionid.id;


--
-- Name: content_library_eventattributechoice; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_eventattributechoice (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    title character varying(200) NOT NULL,
    value character varying(65535) NOT NULL,
    attribute_id integer NOT NULL,
    created_by_id integer,
    updated_by_id integer
);


--
-- Name: content_library_eventattributechoice_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_eventattributechoice_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_eventattributechoice_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_eventattributechoice_id_seq OWNED BY public.content_library_eventattributechoice.id;


--
-- Name: content_library_eventattributechoicecheetahdigitalselectionid; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_eventattributechoicecheetahdigitalselectionid (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    selection_id integer NOT NULL,
    created_by_id integer,
    event_attribute_choice_id integer NOT NULL,
    updated_by_id integer,
    CONSTRAINT content_library_eventattributechoicecheetahd_selection_id_check CHECK ((selection_id >= 0))
);


--
-- Name: content_library_eventattributechoicecheetahdigitalselect_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_eventattributechoicecheetahdigitalselect_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_eventattributechoicecheetahdigitalselect_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_eventattributechoicecheetahdigitalselect_id_seq OWNED BY public.content_library_eventattributechoicecheetahdigitalselectionid.id;


--
-- Name: content_library_eventattributeoracleresponsyscampaignvariable; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_eventattributeoracleresponsyscampaignvariable (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    name character varying(255) NOT NULL,
    created_by_id integer,
    event_attribute_id integer NOT NULL,
    updated_by_id integer
);


--
-- Name: content_library_eventattributeoracleresponsyscampaignvar_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_eventattributeoracleresponsyscampaignvar_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_eventattributeoracleresponsyscampaignvar_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_eventattributeoracleresponsyscampaignvar_id_seq OWNED BY public.content_library_eventattributeoracleresponsyscampaignvariable.id;


--
-- Name: content_library_eventaudience; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_eventaudience (
    id integer NOT NULL,
    priority smallint NOT NULL,
    audience_id integer NOT NULL,
    event_id integer NOT NULL,
    audience_type smallint NOT NULL,
    is_preview_eligible boolean NOT NULL
);


--
-- Name: content_library_eventaudiencefilter_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_eventaudiencefilter_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_eventaudiencefilter_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_eventaudiencefilter_id_seq OWNED BY public.content_library_eventaudience.id;


--
-- Name: content_library_eventcontentblockcreativestats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_eventcontentblockcreativestats (
    id integer NOT NULL,
    report_id character varying(64) NOT NULL,
    content_block_id integer NOT NULL,
    event_id integer NOT NULL
);


--
-- Name: content_library_eventcontentblockcreativestats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_eventcontentblockcreativestats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_eventcontentblockcreativestats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_eventcontentblockcreativestats_id_seq OWNED BY public.content_library_eventcontentblockcreativestats.id;


--
-- Name: content_library_eventcontentblockstats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_eventcontentblockstats (
    id integer NOT NULL,
    report_id character varying(64) NOT NULL,
    event_id integer NOT NULL
);


--
-- Name: content_library_eventcontentblockstats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_eventcontentblockstats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_eventcontentblockstats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_eventcontentblockstats_id_seq OWNED BY public.content_library_eventcontentblockstats.id;


--
-- Name: content_library_eventcreativestats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_eventcreativestats (
    id integer NOT NULL,
    report_id character varying(64) NOT NULL,
    event_id integer NOT NULL
);


--
-- Name: content_library_eventcreativestats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_eventcreativestats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_eventcreativestats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_eventcreativestats_id_seq OWNED BY public.content_library_eventcreativestats.id;


--
-- Name: content_library_eventexperimentstats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_eventexperimentstats (
    id integer NOT NULL,
    report_id character varying(64) NOT NULL,
    event_id integer NOT NULL
);


--
-- Name: content_library_eventexperimentstats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_eventexperimentstats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_eventexperimentstats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_eventexperimentstats_id_seq OWNED BY public.content_library_eventexperimentstats.id;


--
-- Name: content_library_eventoracleresponsysconfig; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_eventoracleresponsysconfig (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    folder_name character varying(255) NOT NULL,
    refining_source_supplemental_table_name character varying(255) NOT NULL,
    refining_source_sql_view_name character varying(255) NOT NULL,
    created_by_id integer,
    event_id integer NOT NULL,
    updated_by_id integer,
    proof_supplemental_table_name character varying(255) NOT NULL,
    seed_supplemental_table_name character varying(255) NOT NULL,
    marketing_program_id integer,
    marketing_strategy_id integer,
    _campaign_variables jsonb NOT NULL,
    campaign_id character varying(255) NOT NULL,
    campaign_name character varying(150) NOT NULL,
    sender_profile_id integer
);


--
-- Name: content_library_eventoracleresponsysconfig_additional_data_13a0; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_eventoracleresponsysconfig_additional_data_13a0 (
    id integer NOT NULL,
    eventoracleresponsysconfig_id integer NOT NULL,
    oracleresponsysadditionaldatasource_id integer NOT NULL
);


--
-- Name: content_library_eventoracleresponsysconfig_additional_da_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_eventoracleresponsysconfig_additional_da_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_eventoracleresponsysconfig_additional_da_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_eventoracleresponsysconfig_additional_da_id_seq OWNED BY public.content_library_eventoracleresponsysconfig_additional_data_13a0.id;


--
-- Name: content_library_eventoracleresponsysconfig_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_eventoracleresponsysconfig_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_eventoracleresponsysconfig_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_eventoracleresponsysconfig_id_seq OWNED BY public.content_library_eventoracleresponsysconfig.id;


--
-- Name: content_library_eventoracleresponsysconfig_suppressions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_eventoracleresponsysconfig_suppressions (
    id integer NOT NULL,
    eventoracleresponsysconfig_id integer NOT NULL,
    oracleresponsyssuppression_id integer NOT NULL
);


--
-- Name: content_library_eventoracleresponsysconfig_suppressions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_eventoracleresponsysconfig_suppressions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_eventoracleresponsysconfig_suppressions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_eventoracleresponsysconfig_suppressions_id_seq OWNED BY public.content_library_eventoracleresponsysconfig_suppressions.id;


--
-- Name: content_library_eventrun; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_eventrun (
    id integer NOT NULL,
    run_id integer NOT NULL,
    event_id integer NOT NULL,
    CONSTRAINT content_library_eventrun_run_id_check CHECK ((run_id >= 0))
);


--
-- Name: content_library_eventrun_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_eventrun_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_eventrun_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_eventrun_id_seq OWNED BY public.content_library_eventrun.id;


--
-- Name: content_library_eventsalesforcemarketingcloudconfig; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_eventsalesforcemarketingcloudconfig (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    data_extension_path character varying(255),
    proof_data_extension_name character varying(255),
    created_by_id integer,
    event_id integer NOT NULL,
    sender_profile_id integer,
    updated_by_id integer,
    seed_data_extension_name character varying(255),
    publication_list_id integer,
    data_extension_names character varying(255)[] NOT NULL,
    message_delivery_type character varying(255) NOT NULL
);


--
-- Name: content_library_eventsalesforcemarketingcloudconfig_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_eventsalesforcemarketingcloudconfig_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_eventsalesforcemarketingcloudconfig_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_eventsalesforcemarketingcloudconfig_id_seq OWNED BY public.content_library_eventsalesforcemarketingcloudconfig.id;


--
-- Name: content_library_eventsalesforcemarketingcloudconfig_suppresa376; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_eventsalesforcemarketingcloudconfig_suppresa376 (
    id integer NOT NULL,
    eventsalesforcemarketingcloudconfig_id integer NOT NULL,
    salesforcemarketingcloudsuppressiondataextension_id integer NOT NULL
);


--
-- Name: content_library_eventsalesforcemarketingcloudconfig_supp_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_eventsalesforcemarketingcloudconfig_supp_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_eventsalesforcemarketingcloudconfig_supp_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_eventsalesforcemarketingcloudconfig_supp_id_seq OWNED BY public.content_library_eventsalesforcemarketingcloudconfig_suppresa376.id;


--
-- Name: content_library_eventstats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_eventstats (
    id integer NOT NULL,
    report_id character varying(64) NOT NULL,
    event_id integer NOT NULL
);


--
-- Name: content_library_eventstats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_eventstats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_eventstats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_eventstats_id_seq OWNED BY public.content_library_eventstats.id;


--
-- Name: content_library_eventstatus; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_eventstatus (
    id integer NOT NULL,
    "timestamp" timestamp with time zone,
    event_id integer NOT NULL,
    user_id integer,
    status character varying(40) NOT NULL
);


--
-- Name: content_library_eventstatus_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_eventstatus_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_eventstatus_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_eventstatus_id_seq OWNED BY public.content_library_eventstatus.id;


--
-- Name: content_library_eventtasklog; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_eventtasklog (
    id integer NOT NULL,
    event_id integer NOT NULL,
    task_id uuid NOT NULL,
    task_name character varying(255) NOT NULL,
    status character varying(50) NOT NULL,
    started_at timestamp with time zone NOT NULL,
    completed_at timestamp with time zone,
    updated_at timestamp with time zone NOT NULL,
    einfo text NOT NULL
);


--
-- Name: content_library_eventtasklog_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_eventtasklog_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_eventtasklog_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_eventtasklog_id_seq OWNED BY public.content_library_eventtasklog.id;


--
-- Name: content_library_eventtrackingpixel; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_eventtrackingpixel (
    id integer NOT NULL,
    uuid uuid NOT NULL,
    url character varying(2000) NOT NULL,
    event_id integer NOT NULL
);


--
-- Name: content_library_eventtrackingpixel_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_eventtrackingpixel_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_eventtrackingpixel_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_eventtrackingpixel_id_seq OWNED BY public.content_library_eventtrackingpixel.id;


--
-- Name: content_library_footertemplate; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_footertemplate (
    id integer NOT NULL,
    title character varying(200) NOT NULL,
    is_default boolean NOT NULL,
    base_template_id integer NOT NULL,
    body_id integer
);


--
-- Name: content_library_footertemplate_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_footertemplate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_footertemplate_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_footertemplate_id_seq OWNED BY public.content_library_footertemplate.id;


--
-- Name: content_library_footertemplatecontentblock; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_footertemplatecontentblock (
    id integer NOT NULL,
    "position" integer NOT NULL,
    content_block_id integer NOT NULL,
    footer_template_id integer NOT NULL,
    CONSTRAINT content_library_footertemplatecontentblock_position_check CHECK (("position" >= 0))
);


--
-- Name: content_library_footertemplatecontentblock_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_footertemplatecontentblock_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_footertemplatecontentblock_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_footertemplatecontentblock_id_seq OWNED BY public.content_library_footertemplatecontentblock.id;


--
-- Name: content_library_freegift; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_freegift (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    min_purchase_amount numeric(7,2),
    min_purchase_quantity numeric(2,0),
    created_by_id integer,
    updated_by_id integer,
    CONSTRAINT content_library_freegift_optional_field_provided CHECK ((public.non_null_count(VARIADIC ARRAY[(min_purchase_amount)::text, (min_purchase_quantity)::text]) = 1))
);


--
-- Name: content_library_freegift_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_freegift_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_freegift_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_freegift_id_seq OWNED BY public.content_library_freegift.id;


--
-- Name: content_library_headertemplate; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_headertemplate (
    id integer NOT NULL,
    title character varying(200) NOT NULL,
    is_default boolean NOT NULL,
    base_template_id integer NOT NULL,
    body_id integer
);


--
-- Name: content_library_headertemplate_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_headertemplate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_headertemplate_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_headertemplate_id_seq OWNED BY public.content_library_headertemplate.id;


--
-- Name: content_library_headertemplatecontentblock; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_headertemplatecontentblock (
    id integer NOT NULL,
    "position" integer NOT NULL,
    content_block_id integer NOT NULL,
    header_template_id integer NOT NULL,
    CONSTRAINT content_library_headertemplatecontentblock_position_check CHECK (("position" >= 0))
);


--
-- Name: content_library_headertemplatecontentblock_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_headertemplatecontentblock_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_headertemplatecontentblock_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_headertemplatecontentblock_id_seq OWNED BY public.content_library_headertemplatecontentblock.id;


--
-- Name: content_library_htmlbundle; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_htmlbundle (
    id integer NOT NULL,
    title character varying(200) NOT NULL,
    html text NOT NULL,
    client_id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    created_by_id integer,
    updated_at timestamp with time zone NOT NULL,
    updated_by_id integer
);


--
-- Name: content_library_htmlbundle_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_htmlbundle_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_htmlbundle_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_htmlbundle_id_seq OWNED BY public.content_library_htmlbundle.id;


--
-- Name: content_library_htmlbundleimage; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_htmlbundleimage (
    id integer NOT NULL,
    html_bundle_id integer NOT NULL,
    image_id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    created_by_id integer,
    updated_at timestamp with time zone NOT NULL,
    updated_by_id integer
);


--
-- Name: content_library_htmlbundleimage_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_htmlbundleimage_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_htmlbundleimage_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_htmlbundleimage_id_seq OWNED BY public.content_library_htmlbundleimage.id;


--
-- Name: content_library_htmlbundlelink; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_htmlbundlelink (
    id integer NOT NULL,
    html_bundle_id integer NOT NULL,
    link_id integer NOT NULL
);


--
-- Name: content_library_htmlbundlelink_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_htmlbundlelink_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_htmlbundlelink_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_htmlbundlelink_id_seq OWNED BY public.content_library_htmlbundlelink.id;


--
-- Name: content_library_image; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_image (
    id integer NOT NULL,
    uuid uuid NOT NULL,
    filename character varying(255) NOT NULL,
    contents_md5 character varying(32) NOT NULL,
    field_type smallint NOT NULL,
    source character varying(4000) NOT NULL,
    url character varying(65535) NOT NULL,
    client_id integer NOT NULL,
    type smallint NOT NULL,
    created_at timestamp with time zone NOT NULL,
    created_by_id integer,
    updated_at timestamp with time zone NOT NULL,
    updated_by_id integer,
    short_uuid character varying(7) NOT NULL,
    cdn_source character varying(4000) NOT NULL
);


--
-- Name: content_library_image_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_image_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_image_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_image_id_seq OWNED BY public.content_library_image.id;


--
-- Name: content_library_imagelayout; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_imagelayout (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    structure jsonb NOT NULL,
    client_id integer NOT NULL,
    created_by_id integer,
    updated_by_id integer
);


--
-- Name: content_library_imagelayout_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_imagelayout_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_imagelayout_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_imagelayout_id_seq OWNED BY public.content_library_imagelayout.id;


--
-- Name: content_library_imageslice; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_imageslice (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    alt_text character varying(1000) NOT NULL,
    title_text character varying(1000) NOT NULL,
    client_id integer NOT NULL,
    created_by_id integer,
    image_id integer,
    image_layout_id integer NOT NULL,
    link_id integer,
    updated_by_id integer
);


--
-- Name: content_library_imageslice_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_imageslice_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_imageslice_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_imageslice_id_seq OWNED BY public.content_library_imageslice.id;


--
-- Name: content_library_inboxpreview; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_inboxpreview (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    subject_line_type smallint NOT NULL,
    subject_line_static character varying(255) NOT NULL,
    subject_line_prefix_type smallint NOT NULL,
    subject_line_prefix_static character varying(255) NOT NULL,
    subject_line_suffix_type smallint NOT NULL,
    subject_line_suffix_static character varying(255) NOT NULL,
    preheader_type smallint NOT NULL,
    preview_text_static character varying(255) NOT NULL,
    preheader_text_static character varying(255) NOT NULL,
    preheader_url_static character varying(2000) NOT NULL,
    use_preheader_text_as_preview_text boolean NOT NULL,
    promotion_card_type smallint NOT NULL,
    discount_offer_type smallint NOT NULL,
    created_by_id integer,
    creatives_variant_id integer NOT NULL,
    discount_offer_dynamic_id integer,
    event_audience_id integer NOT NULL,
    preheader_dynamic_id integer,
    preheader_link_static_id integer,
    promotion_card_dynamic_id integer,
    subject_line_dynamic_id integer,
    subject_line_prefix_dynamic_id integer,
    subject_line_suffix_dynamic_id integer,
    updated_by_id integer
);


--
-- Name: content_library_inboxpreview_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_inboxpreview_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_inboxpreview_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_inboxpreview_id_seq OWNED BY public.content_library_inboxpreview.id;


--
-- Name: content_library_invitation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_invitation (
    id integer NOT NULL,
    accepted boolean NOT NULL,
    key character varying(64) NOT NULL,
    sent timestamp with time zone,
    created timestamp with time zone NOT NULL,
    email character varying(255) NOT NULL,
    client_id integer NOT NULL,
    inviter_id integer
);


--
-- Name: content_library_invitation_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_invitation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_invitation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_invitation_id_seq OWNED BY public.content_library_invitation.id;


--
-- Name: content_library_layout; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_layout (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    client_id integer NOT NULL,
    created_by_id integer,
    updated_by_id integer,
    _structure jsonb NOT NULL,
    version smallint NOT NULL
);


--
-- Name: content_library_layout_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_layout_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_layout_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_layout_id_seq OWNED BY public.content_library_layout.id;


--
-- Name: content_library_link; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_link (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    url character varying(65535) NOT NULL,
    client_id integer NOT NULL,
    created_by_id integer,
    updated_by_id integer,
    link_group_id integer,
    query_string_parameters character varying(255)[] NOT NULL,
    uuid uuid NOT NULL,
    short_uuid character varying(7) NOT NULL,
    _tracking_parameters jsonb NOT NULL,
    enable_tracking boolean NOT NULL
);


--
-- Name: content_library_linkcategory; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_linkcategory (
    id integer NOT NULL,
    title character varying(200) NOT NULL,
    value character varying(200) NOT NULL,
    "position" integer NOT NULL,
    client_id integer NOT NULL,
    CONSTRAINT content_library_linkcategory_position_check CHECK (("position" >= 0))
);


--
-- Name: content_library_linkcategory_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_linkcategory_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_linkcategory_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_linkcategory_id_seq OWNED BY public.content_library_linkcategory.id;


--
-- Name: content_library_linkgroup; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_linkgroup (
    id integer NOT NULL,
    name character varying(200) NOT NULL,
    client_id integer NOT NULL
);


--
-- Name: content_library_linkgroup_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_linkgroup_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_linkgroup_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_linkgroup_id_seq OWNED BY public.content_library_linkgroup.id;


--
-- Name: content_library_movableinkcreative; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_movableinkcreative (
    id integer NOT NULL,
    open_pixel character varying(2000) NOT NULL,
    creative_id integer NOT NULL
);


--
-- Name: content_library_movableinkcreative_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_movableinkcreative_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_movableinkcreative_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_movableinkcreative_id_seq OWNED BY public.content_library_movableinkcreative.id;


--
-- Name: content_library_movableinkintegration; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_movableinkintegration (
    id integer NOT NULL,
    access_token bytea NOT NULL,
    expires_at integer NOT NULL,
    refresh_token bytea NOT NULL,
    user_id integer NOT NULL
);


--
-- Name: content_library_movableinkintegration_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_movableinkintegration_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_movableinkintegration_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_movableinkintegration_id_seq OWNED BY public.content_library_movableinkintegration.id;


--
-- Name: content_library_neweligiblecreative; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_neweligiblecreative (
    id integer NOT NULL,
    included boolean NOT NULL,
    configured_at timestamp with time zone NOT NULL,
    configured_by_id integer,
    creative_id integer NOT NULL,
    section_variant_id integer NOT NULL
);


--
-- Name: content_library_neweligiblecreative_id_seq1; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_neweligiblecreative_id_seq1
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_neweligiblecreative_id_seq1; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_neweligiblecreative_id_seq1 OWNED BY public.content_library_neweligiblecreative.id;


--
-- Name: content_library_newlink_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_newlink_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_newlink_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_newlink_id_seq OWNED BY public.content_library_link.id;


--
-- Name: content_library_neworacleresponsysclientconfig; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_neworacleresponsysclientconfig (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    data_extraction_key character varying(255) NOT NULL,
    data_extraction_field_type character varying(255) NOT NULL,
    default_folder_name character varying(255),
    client_id integer NOT NULL,
    created_by_id integer,
    profile_list_id integer NOT NULL,
    updated_by_id integer,
    notification_emails character varying(255)[] NOT NULL,
    auto_close_date date,
    auto_close_option character varying(255) NOT NULL,
    auto_close_value integer,
    closed_campaign_url character varying(200),
    unsubscribe_form character varying(255),
    unsubscribe_option character varying(255) NOT NULL
);


--
-- Name: content_library_neworacleresponsysclientconfig_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_neworacleresponsysclientconfig_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_neworacleresponsysclientconfig_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_neworacleresponsysclientconfig_id_seq OWNED BY public.content_library_neworacleresponsysclientconfig.id;


--
-- Name: content_library_senddatetime; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_senddatetime (
    id integer NOT NULL,
    send_datetime_range tstzrange NOT NULL,
    send_time_personalization_variant_id integer NOT NULL
);


--
-- Name: content_library_newsenddatetime_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_newsenddatetime_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_newsenddatetime_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_newsenddatetime_id_seq OWNED BY public.content_library_senddatetime.id;


--
-- Name: content_library_offer; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_offer (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    offer_type smallint NOT NULL,
    client_id integer NOT NULL,
    created_by_id integer,
    updated_by_id integer,
    content_type_id integer,
    offer_detail_id integer,
    CONSTRAINT content_library_offer_offer_detail_id_check CHECK ((offer_detail_id >= 0))
);


--
-- Name: content_library_offer_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_offer_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_offer_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_offer_id_seq OWNED BY public.content_library_offer.id;


--
-- Name: content_library_oracleresponsys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_oracleresponsys (
    emailserviceprovider_ptr_id integer NOT NULL,
    environment smallint NOT NULL,
    account_name character varying(255) NOT NULL,
    link_metadata_requires_category boolean NOT NULL,
    link_metadata_requires_name boolean NOT NULL
);


--
-- Name: content_library_oracleresponsysadditionaldatasource; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_oracleresponsysadditionaldatasource (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    name character varying(255) NOT NULL,
    folder character varying(255) NOT NULL,
    "default" boolean NOT NULL,
    client_id integer NOT NULL,
    created_by_id integer,
    updated_by_id integer
);


--
-- Name: content_library_oracleresponsysadditionaldatasource_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_oracleresponsysadditionaldatasource_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_oracleresponsysadditionaldatasource_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_oracleresponsysadditionaldatasource_id_seq OWNED BY public.content_library_oracleresponsysadditionaldatasource.id;


--
-- Name: content_library_oracleresponsyscampaignvariable; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_oracleresponsyscampaignvariable (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    title character varying(200) NOT NULL,
    default_value character varying(255) NOT NULL,
    "position" integer NOT NULL,
    max_length integer,
    field_type smallint NOT NULL,
    client_id integer NOT NULL,
    created_by_id integer,
    updated_by_id integer,
    CONSTRAINT content_library_oracleresponsyscampaignvariable_position_check CHECK (("position" >= 0))
);


--
-- Name: content_library_oracleresponsyscampaignvariable_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_oracleresponsyscampaignvariable_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_oracleresponsyscampaignvariable_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_oracleresponsyscampaignvariable_id_seq OWNED BY public.content_library_oracleresponsyscampaignvariable.id;


--
-- Name: content_library_oracleresponsyscampaignvariablechoice; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_oracleresponsyscampaignvariablechoice (
    id integer NOT NULL,
    title character varying(200) NOT NULL,
    value character varying(255) NOT NULL,
    "position" integer NOT NULL,
    campaign_variable_id integer NOT NULL,
    CONSTRAINT content_library_oracleresponsyscampaignvariablec_position_check CHECK (("position" >= 0))
);


--
-- Name: content_library_oracleresponsyscampaignvariablechoice_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_oracleresponsyscampaignvariablechoice_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_oracleresponsyscampaignvariablechoice_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_oracleresponsyscampaignvariablechoice_id_seq OWNED BY public.content_library_oracleresponsyscampaignvariablechoice.id;


--
-- Name: content_library_oracleresponsysclientconfig; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_oracleresponsysclientconfig (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    list_name character varying(255) NOT NULL,
    created_by_id integer,
    esp_id integer NOT NULL,
    updated_by_id integer,
    closed_campaign_url character varying(255) NOT NULL,
    external_campaign_code_event_attribute_id integer,
    from_name character varying(255) NOT NULL,
    list_folder_name character varying(255) NOT NULL,
    marketing_program character varying(255) NOT NULL,
    marketing_strategy character varying(255) NOT NULL,
    seed_list_folder_name character varying(255) NOT NULL,
    seed_list_name character varying(255) NOT NULL,
    segment_tracking_column_name character varying(255) NOT NULL,
    suppression_list_name character varying(255) NOT NULL,
    from_email character varying(255) NOT NULL,
    reply_to_email_address character varying(255) NOT NULL,
    additional_pets_event_attribute_id integer,
    unsubscribe_form character varying(255) NOT NULL,
    unsubscribe_type smallint NOT NULL,
    campaign_folder character varying(255) NOT NULL,
    auto_close_option text NOT NULL,
    auto_close_value smallint NOT NULL
);


--
-- Name: content_library_oracleresponsysclientconfig_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_oracleresponsysclientconfig_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_oracleresponsysclientconfig_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_oracleresponsysclientconfig_id_seq OWNED BY public.content_library_oracleresponsysclientconfig.id;


--
-- Name: content_library_oracleresponsyscreativecontentblockdocument; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_oracleresponsyscreativecontentblockdocument (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    document_name character varying(150) NOT NULL,
    content_block_id integer NOT NULL,
    created_by_id integer,
    creative_id integer NOT NULL,
    updated_by_id integer,
    contents_md5 character varying(32) NOT NULL,
    start_end_datetime tstzrange
);


--
-- Name: content_library_oracleresponsyscreativecontentblockdocum_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_oracleresponsyscreativecontentblockdocum_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_oracleresponsyscreativecontentblockdocum_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_oracleresponsyscreativecontentblockdocum_id_seq OWNED BY public.content_library_oracleresponsyscreativecontentblockdocument.id;


--
-- Name: content_library_oracleresponsyscreativediscountofferdocument; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_oracleresponsyscreativediscountofferdocument (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    created_by_id integer,
    document_id integer NOT NULL,
    promotion_redemption_id integer NOT NULL,
    updated_by_id integer
);


--
-- Name: content_library_oracleresponsyscreativedocument; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_oracleresponsyscreativedocument (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    document_name character varying(150) NOT NULL,
    contents_md5 character varying(32) NOT NULL,
    document_type smallint NOT NULL,
    created_by_id integer,
    creative_id integer NOT NULL,
    updated_by_id integer,
    contentblock_id integer
);


--
-- Name: content_library_oracleresponsyscreativedocument_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_oracleresponsyscreativedocument_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_oracleresponsyscreativedocument_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_oracleresponsyscreativedocument_id_seq OWNED BY public.content_library_oracleresponsyscreativedocument.id;


--
-- Name: content_library_oracleresponsyscreativepromotiondocument_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_oracleresponsyscreativepromotiondocument_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_oracleresponsyscreativepromotiondocument_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_oracleresponsyscreativepromotiondocument_id_seq OWNED BY public.content_library_oracleresponsyscreativediscountofferdocument.id;


--
-- Name: content_library_oracleresponsyslaunch; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_oracleresponsyslaunch (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    campaign_id character varying(255) NOT NULL,
    launch_id character varying(255) NOT NULL,
    launch_state smallint NOT NULL,
    created_by_id integer,
    event_id integer NOT NULL,
    updated_by_id integer,
    launch_datetime timestamp with time zone,
    launch_type smallint
);


--
-- Name: content_library_oracleresponsyseventmetadata_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_oracleresponsyseventmetadata_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_oracleresponsyseventmetadata_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_oracleresponsyseventmetadata_id_seq OWNED BY public.content_library_oracleresponsyslaunch.id;


--
-- Name: content_library_oracleresponsyslinkmetadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_oracleresponsyslinkmetadata (
    id integer NOT NULL,
    name character varying(200) NOT NULL,
    enable_tracking boolean NOT NULL,
    category_id integer,
    link_id integer NOT NULL,
    oracle_responsys_id integer NOT NULL
);


--
-- Name: content_library_oracleresponsyslinkmetadata_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_oracleresponsyslinkmetadata_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_oracleresponsyslinkmetadata_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_oracleresponsyslinkmetadata_id_seq OWNED BY public.content_library_oracleresponsyslinkmetadata.id;


--
-- Name: content_library_oracleresponsyslist; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_oracleresponsyslist (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    name character varying(255) NOT NULL,
    folder character varying(255) NOT NULL,
    list_type smallint NOT NULL,
    "default" boolean NOT NULL,
    client_id integer NOT NULL,
    created_by_id integer,
    updated_by_id integer
);


--
-- Name: content_library_oracleresponsyslist_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_oracleresponsyslist_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_oracleresponsyslist_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_oracleresponsyslist_id_seq OWNED BY public.content_library_oracleresponsyslist.id;


--
-- Name: content_library_oracleresponsysmarketingprogram; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_oracleresponsysmarketingprogram (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    name character varying(255) NOT NULL,
    "default" boolean NOT NULL,
    client_id integer NOT NULL,
    created_by_id integer,
    updated_by_id integer
);


--
-- Name: content_library_oracleresponsysmarketingprogram_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_oracleresponsysmarketingprogram_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_oracleresponsysmarketingprogram_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_oracleresponsysmarketingprogram_id_seq OWNED BY public.content_library_oracleresponsysmarketingprogram.id;


--
-- Name: content_library_oracleresponsysmarketingstrategy; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_oracleresponsysmarketingstrategy (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    name character varying(255) NOT NULL,
    "default" boolean NOT NULL,
    client_id integer NOT NULL,
    created_by_id integer,
    updated_by_id integer
);


--
-- Name: content_library_oracleresponsysmarketingstrategy_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_oracleresponsysmarketingstrategy_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_oracleresponsysmarketingstrategy_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_oracleresponsysmarketingstrategy_id_seq OWNED BY public.content_library_oracleresponsysmarketingstrategy.id;


--
-- Name: content_library_oracleresponsyssenderprofile; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_oracleresponsyssenderprofile (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    display_name character varying(255) NOT NULL,
    from_name character varying(255) NOT NULL,
    from_email character varying(254) NOT NULL,
    reply_to_email character varying(254) NOT NULL,
    "default" boolean NOT NULL,
    client_id integer NOT NULL,
    created_by_id integer,
    updated_by_id integer
);


--
-- Name: content_library_oracleresponsyssenderprofile_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_oracleresponsyssenderprofile_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_oracleresponsyssenderprofile_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_oracleresponsyssenderprofile_id_seq OWNED BY public.content_library_oracleresponsyssenderprofile.id;


--
-- Name: content_library_oracleresponsysstaticcontentblockdocument; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_oracleresponsysstaticcontentblockdocument (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    document_name character varying(150) NOT NULL,
    contents_md5 character varying(32) NOT NULL,
    content_block_id integer NOT NULL,
    created_by_id integer,
    updated_by_id integer
);


--
-- Name: content_library_oracleresponsysstaticcontentblockdocumen_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_oracleresponsysstaticcontentblockdocumen_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_oracleresponsysstaticcontentblockdocumen_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_oracleresponsysstaticcontentblockdocumen_id_seq OWNED BY public.content_library_oracleresponsysstaticcontentblockdocument.id;


--
-- Name: content_library_oracleresponsyssuppression; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_oracleresponsyssuppression (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    name character varying(255) NOT NULL,
    folder character varying(255) NOT NULL,
    "default" boolean NOT NULL,
    client_id integer NOT NULL,
    created_by_id integer,
    updated_by_id integer
);


--
-- Name: content_library_oracleresponsyssuppression_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_oracleresponsyssuppression_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_oracleresponsyssuppression_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_oracleresponsyssuppression_id_seq OWNED BY public.content_library_oracleresponsyssuppression.id;


--
-- Name: content_library_persadocampaign; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_persadocampaign (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    title character varying(200) NOT NULL,
    campaign_id integer NOT NULL,
    subject_line_script text NOT NULL,
    body_amp_script text NOT NULL,
    client_id integer NOT NULL,
    created_by_id integer,
    updated_by_id integer,
    CONSTRAINT content_library_persadocampaign_campaign_id_check CHECK ((campaign_id >= 0))
);


--
-- Name: content_library_persadocampaign_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_persadocampaign_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_persadocampaign_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_persadocampaign_id_seq OWNED BY public.content_library_persadocampaign.id;


--
-- Name: content_library_predefinedlayoutstructure; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_predefinedlayoutstructure (
    id integer NOT NULL,
    title character varying(255) NOT NULL,
    structure jsonb NOT NULL
);


--
-- Name: content_library_predefinedlayoutstructure_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_predefinedlayoutstructure_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_predefinedlayoutstructure_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_predefinedlayoutstructure_id_seq OWNED BY public.content_library_predefinedlayoutstructure.id;


--
-- Name: content_library_productcollection; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_productcollection (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    created_by_id integer,
    updated_by_id integer
);


--
-- Name: content_library_productcollection_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_productcollection_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_productcollection_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_productcollection_id_seq OWNED BY public.content_library_productcollection.id;


--
-- Name: content_library_productcollection_product_values; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_productcollection_product_values (
    id integer NOT NULL,
    productcollection_id integer NOT NULL,
    productvalue_id integer NOT NULL
);


--
-- Name: content_library_productcollection_product_values_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_productcollection_product_values_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_productcollection_product_values_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_productcollection_product_values_id_seq OWNED BY public.content_library_productcollection_product_values.id;


--
-- Name: content_library_productfield; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_productfield (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    id_field_name character varying(200) NOT NULL,
    description_field_name character varying(200) NOT NULL,
    display_name character varying(2000) NOT NULL,
    client_id integer NOT NULL,
    created_by_id integer,
    updated_by_id integer,
    "position" integer NOT NULL,
    required boolean NOT NULL,
    CONSTRAINT content_library_productfield_position_check CHECK (("position" >= 0))
);


--
-- Name: content_library_productfield_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_productfield_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_productfield_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_productfield_id_seq OWNED BY public.content_library_productfield.id;


--
-- Name: content_library_productvalue; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_productvalue (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    external_id character varying(500) NOT NULL,
    description text NOT NULL,
    created_by_id integer,
    product_field_id integer NOT NULL,
    updated_by_id integer
);


--
-- Name: content_library_productvalue_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_productvalue_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_productvalue_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_productvalue_id_seq OWNED BY public.content_library_productvalue.id;


--
-- Name: content_library_prohibitedcreativeproductcollection; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_prohibitedcreativeproductcollection (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    created_by_id integer,
    creative_id integer NOT NULL,
    productcollection_id integer NOT NULL,
    updated_by_id integer
);


--
-- Name: content_library_prohibitedcreativeproductcollection_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_prohibitedcreativeproductcollection_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_prohibitedcreativeproductcollection_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_prohibitedcreativeproductcollection_id_seq OWNED BY public.content_library_prohibitedcreativeproductcollection.id;


--
-- Name: content_library_prohibitedcreativetag; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_prohibitedcreativetag (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    created_by_id integer,
    creative_id integer NOT NULL,
    tag_id integer NOT NULL,
    updated_by_id integer
);


--
-- Name: content_library_prohibitedcreativetag_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_prohibitedcreativetag_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_prohibitedcreativetag_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_prohibitedcreativetag_id_seq OWNED BY public.content_library_prohibitedcreativetag.id;


--
-- Name: content_library_promotion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_promotion (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    title character varying(255) NOT NULL,
    serialized boolean NOT NULL,
    description character varying(200) NOT NULL,
    client_id integer NOT NULL,
    created_by_id integer,
    updated_by_id integer,
    use_default_description boolean NOT NULL
);


--
-- Name: content_library_promotion_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_promotion_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_promotion_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_promotion_id_seq OWNED BY public.content_library_promotion.id;


--
-- Name: content_library_promotionoffer; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_promotionoffer (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    offer_id integer NOT NULL,
    promotion_id integer NOT NULL
);


--
-- Name: content_library_promotionoffer_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_promotionoffer_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_promotionoffer_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_promotionoffer_id_seq OWNED BY public.content_library_promotionoffer.id;


--
-- Name: content_library_promotionredemption; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_promotionredemption (
    id integer NOT NULL,
    start_end_datetime tstzrange NOT NULL,
    code character varying(255) NOT NULL,
    promotion_id integer NOT NULL
);


--
-- Name: content_library_promotionredemption_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_promotionredemption_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_promotionredemption_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_promotionredemption_id_seq OWNED BY public.content_library_promotionredemption.id;


--
-- Name: content_library_proxycontrolexperiment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_proxycontrolexperiment (
    baseexperiment_ptr_id integer NOT NULL
);


--
-- Name: content_library_proxycontroltreatment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_proxycontroltreatment (
    basetreatment_ptr_id integer NOT NULL,
    "order" smallint NOT NULL,
    experiment_id integer NOT NULL
);


--
-- Name: content_library_proxycontrolvariant; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_proxycontrolvariant (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    created_by_id integer,
    event_id integer NOT NULL,
    treatment_id integer,
    updated_by_id integer
);


--
-- Name: content_library_proxycontrolvariant_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_proxycontrolvariant_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_proxycontrolvariant_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_proxycontrolvariant_id_seq OWNED BY public.content_library_proxycontrolvariant.id;


--
-- Name: content_library_quantitydiscount; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_quantitydiscount (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    amount numeric(9,2),
    fixed_price numeric(7,2),
    percentage numeric(3,0),
    purchase_quantity numeric(5,2) NOT NULL,
    discount_quantity numeric(5,2) NOT NULL,
    created_by_id integer,
    updated_by_id integer,
    CONSTRAINT content_library_quantitydiscount_optional_field_provided CHECK ((public.non_null_count(VARIADIC ARRAY[(fixed_price)::text, (amount)::text, (percentage)::text]) = 1))
);


--
-- Name: content_library_quantitydiscount_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_quantitydiscount_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_quantitydiscount_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_quantitydiscount_id_seq OWNED BY public.content_library_quantitydiscount.id;


--
-- Name: content_library_querystringparameter; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_querystringparameter (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    key character varying(255) NOT NULL,
    value character varying(255) NOT NULL,
    level smallint NOT NULL,
    client_id integer NOT NULL,
    created_by_id integer,
    updated_by_id integer,
    "position" smallint,
    is_external boolean NOT NULL
);


--
-- Name: content_library_querystringparameter_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_querystringparameter_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_querystringparameter_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_querystringparameter_id_seq OWNED BY public.content_library_querystringparameter.id;


--
-- Name: content_library_recommendationrun; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_recommendationrun (
    id integer NOT NULL,
    run_id integer NOT NULL,
    run_type character varying(20) NOT NULL,
    client_id integer NOT NULL,
    CONSTRAINT content_library_recommendationrun_run_id_check CHECK ((run_id >= 0))
);


--
-- Name: content_library_recommendationrun_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_recommendationrun_events (
    id integer NOT NULL,
    recommendationrun_id integer NOT NULL,
    event_id integer NOT NULL
);


--
-- Name: content_library_recommendationrun_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_recommendationrun_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_recommendationrun_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_recommendationrun_events_id_seq OWNED BY public.content_library_recommendationrun_events.id;


--
-- Name: content_library_recommendationrun_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_recommendationrun_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_recommendationrun_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_recommendationrun_id_seq OWNED BY public.content_library_recommendationrun.id;


--
-- Name: content_library_recommendationrunlog; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_recommendationrunlog (
    id integer NOT NULL,
    status character varying(20) NOT NULL,
    "timestamp" timestamp with time zone NOT NULL,
    event_id integer NOT NULL,
    recommendation_run_id integer NOT NULL
);


--
-- Name: content_library_recommendationrunlog_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_recommendationrunlog_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_recommendationrunlog_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_recommendationrunlog_id_seq OWNED BY public.content_library_recommendationrunlog.id;


--
-- Name: content_library_recommendationsversion_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_recommendationsversion_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_recommendationsversion_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_recommendationsversion_id_seq OWNED BY public.content_library_contentpersonalizationmodel.id;


--
-- Name: content_library_renderedcreative; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_renderedcreative (
    id integer NOT NULL,
    thumbnail character varying(65535) NOT NULL,
    content_block_id integer NOT NULL,
    creative_id integer NOT NULL
);


--
-- Name: content_library_renderedcreative_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_renderedcreative_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_renderedcreative_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_renderedcreative_id_seq OWNED BY public.content_library_renderedcreative.id;


--
-- Name: content_library_rewardsmultiplier; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_rewardsmultiplier (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    savings_type smallint NOT NULL,
    min_purchase_amount numeric(7,2),
    min_purchase_quantity numeric(2,0),
    multiplier numeric(3,0) NOT NULL,
    created_by_id integer,
    updated_by_id integer
);


--
-- Name: content_library_rewardsmultiplier_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_rewardsmultiplier_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_rewardsmultiplier_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_rewardsmultiplier_id_seq OWNED BY public.content_library_rewardsmultiplier.id;


--
-- Name: content_library_salesforcemarketingcloud; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_salesforcemarketingcloud (
    emailserviceprovider_ptr_id integer NOT NULL,
    ftp_username character varying(255) NOT NULL,
    ftp_password bytea NOT NULL,
    notify_email character varying(255),
    ftp_transfer_location character varying(255) NOT NULL,
    link_metadata_requires_alias boolean NOT NULL,
    max_asset_filename_length integer NOT NULL,
    member_id character varying(255)
);


--
-- Name: content_library_salesforcemarketingcloudcreativecontentblocaf9f; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_salesforcemarketingcloudcreativecontentblocaf9f (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    asset_id integer NOT NULL,
    content_block_name character varying(100) NOT NULL,
    content_block_id integer NOT NULL,
    created_by_id integer,
    creative_id integer NOT NULL,
    updated_by_id integer,
    contents_md5 character varying(32) NOT NULL
);


--
-- Name: content_library_salesforcemarketingcloudcreativecontentb_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_salesforcemarketingcloudcreativecontentb_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_salesforcemarketingcloudcreativecontentb_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_salesforcemarketingcloudcreativecontentb_id_seq OWNED BY public.content_library_salesforcemarketingcloudcreativecontentblocaf9f.id;


--
-- Name: content_library_salesforcemarketingcloudcreativediscountoff3b11; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_salesforcemarketingcloudcreativediscountoff3b11 (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    created_by_id integer,
    document_id integer NOT NULL,
    promotion_redemption_id integer NOT NULL,
    updated_by_id integer
);


--
-- Name: content_library_salesforcemarketingcloudcreativedocument; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_salesforcemarketingcloudcreativedocument (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    asset_id integer NOT NULL,
    content_block_name character varying(100) NOT NULL,
    document_type smallint NOT NULL,
    created_by_id integer,
    creative_id integer NOT NULL,
    updated_by_id integer,
    contents_md5 character varying(32) NOT NULL,
    contentblock_id integer
);


--
-- Name: content_library_salesforcemarketingcloudcreativedocument_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_salesforcemarketingcloudcreativedocument_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_salesforcemarketingcloudcreativedocument_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_salesforcemarketingcloudcreativedocument_id_seq OWNED BY public.content_library_salesforcemarketingcloudcreativedocument.id;


--
-- Name: content_library_salesforcemarketingcloudcreativepromotio_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_salesforcemarketingcloudcreativepromotio_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_salesforcemarketingcloudcreativepromotio_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_salesforcemarketingcloudcreativepromotio_id_seq OWNED BY public.content_library_salesforcemarketingcloudcreativediscountoff3b11.id;


--
-- Name: content_library_salesforcemarketingcloudsend; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_salesforcemarketingcloudsend (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    send_id character varying(255) NOT NULL,
    created_by_id integer,
    event_id integer NOT NULL,
    updated_by_id integer,
    send_datetime timestamp with time zone
);


--
-- Name: content_library_salesforcemarketingcloudeventmetadata_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_salesforcemarketingcloudeventmetadata_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_salesforcemarketingcloudeventmetadata_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_salesforcemarketingcloudeventmetadata_id_seq OWNED BY public.content_library_salesforcemarketingcloudsend.id;


--
-- Name: content_library_salesforcemarketingcloudintegration; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_salesforcemarketingcloudintegration (
    id integer NOT NULL,
    logged_in boolean NOT NULL,
    subdomain character varying(255) NOT NULL,
    refresh_token bytea NOT NULL,
    client_id integer NOT NULL,
    user_id integer NOT NULL
);


--
-- Name: content_library_salesforcemarketingcloudintegration_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_salesforcemarketingcloudintegration_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_salesforcemarketingcloudintegration_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_salesforcemarketingcloudintegration_id_seq OWNED BY public.content_library_salesforcemarketingcloudintegration.id;


--
-- Name: content_library_salesforcemarketingcloudlinkmetadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_salesforcemarketingcloudlinkmetadata (
    id integer NOT NULL,
    alias character varying(200) NOT NULL,
    enable_deep_links boolean NOT NULL,
    link_id integer NOT NULL,
    enable_conversion_tracking boolean NOT NULL,
    salesforce_marketing_cloud_id integer NOT NULL
);


--
-- Name: content_library_salesforcemarketingcloudlinkmetadata_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_salesforcemarketingcloudlinkmetadata_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_salesforcemarketingcloudlinkmetadata_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_salesforcemarketingcloudlinkmetadata_id_seq OWNED BY public.content_library_salesforcemarketingcloudlinkmetadata.id;


--
-- Name: content_library_salesforcemarketingcloudmessagedeliveryconfig; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_salesforcemarketingcloudmessagedeliveryconfig (
    id integer NOT NULL,
    enable_standard_delivery boolean NOT NULL,
    enable_delayed_delivery_by_message_transfer_agents boolean NOT NULL,
    enable_delayed_delivery_by_outbound_message_servers boolean NOT NULL,
    client_id integer NOT NULL
);


--
-- Name: content_library_salesforcemarketingcloudmessagedeliveryc_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_salesforcemarketingcloudmessagedeliveryc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_salesforcemarketingcloudmessagedeliveryc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_salesforcemarketingcloudmessagedeliveryc_id_seq OWNED BY public.content_library_salesforcemarketingcloudmessagedeliveryconfig.id;


--
-- Name: content_library_salesforcemarketingcloudpublicationlist; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_salesforcemarketingcloudpublicationlist (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    "default" boolean NOT NULL,
    client_id integer NOT NULL
);


--
-- Name: content_library_salesforcemarketingcloudpublicationlist_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_salesforcemarketingcloudpublicationlist_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_salesforcemarketingcloudpublicationlist_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_salesforcemarketingcloudpublicationlist_id_seq OWNED BY public.content_library_salesforcemarketingcloudpublicationlist.id;


--
-- Name: content_library_salesforcemarketingcloudsenderprofile; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_salesforcemarketingcloudsenderprofile (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    display_name character varying(255) NOT NULL,
    client_id integer NOT NULL,
    "default" boolean NOT NULL
);


--
-- Name: content_library_salesforcemarketingcloudsenderprofile_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_salesforcemarketingcloudsenderprofile_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_salesforcemarketingcloudsenderprofile_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_salesforcemarketingcloudsenderprofile_id_seq OWNED BY public.content_library_salesforcemarketingcloudsenderprofile.id;


--
-- Name: content_library_salesforcemarketingcloudstaticcontentblockda7ea; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_salesforcemarketingcloudstaticcontentblockda7ea (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    asset_id integer NOT NULL,
    content_block_name character varying(100) NOT NULL,
    contents_md5 character varying(32) NOT NULL,
    content_block_id integer NOT NULL,
    created_by_id integer,
    updated_by_id integer
);


--
-- Name: content_library_salesforcemarketingcloudstaticcontentblo_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_salesforcemarketingcloudstaticcontentblo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_salesforcemarketingcloudstaticcontentblo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_salesforcemarketingcloudstaticcontentblo_id_seq OWNED BY public.content_library_salesforcemarketingcloudstaticcontentblockda7ea.id;


--
-- Name: content_library_salesforcemarketingcloudsuppressiondataexte91a1; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_salesforcemarketingcloudsuppressiondataexte91a1 (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    object_id character varying(255) NOT NULL,
    "default" boolean NOT NULL,
    client_id integer NOT NULL
);


--
-- Name: content_library_salesforcemarketingcloudsuppressiondatae_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_salesforcemarketingcloudsuppressiondatae_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_salesforcemarketingcloudsuppressiondatae_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_salesforcemarketingcloudsuppressiondatae_id_seq OWNED BY public.content_library_salesforcemarketingcloudsuppressiondataexte91a1.id;


--
-- Name: content_library_section; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_section (
    id integer NOT NULL,
    "position" integer NOT NULL,
    is_primary boolean NOT NULL,
    contentblock_id integer NOT NULL,
    event_id integer NOT NULL,
    template_type character varying(10) NOT NULL,
    template_variant_id integer,
    final_position integer NOT NULL,
    template_type_id integer NOT NULL,
    CONSTRAINT content_library_section_final_position_check CHECK ((final_position >= 0)),
    CONSTRAINT content_library_section_position_check CHECK (("position" >= 0)),
    CONSTRAINT content_library_section_template_type_id_check CHECK ((template_type_id >= 0))
);


--
-- Name: content_library_section_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_section_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_section_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_section_id_seq OWNED BY public.content_library_section.id;


--
-- Name: content_library_senddatetimeexperiment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_senddatetimeexperiment (
    baseexperiment_ptr_id integer NOT NULL
);


--
-- Name: content_library_senddatetimetreatment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_senddatetimetreatment (
    basetreatment_ptr_id integer NOT NULL,
    "order" smallint NOT NULL,
    experiment_id integer NOT NULL
);


--
-- Name: content_library_sendtimepersonalizationvariant; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_sendtimepersonalizationvariant (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    send_time_type smallint NOT NULL,
    created_by_id integer,
    event_id integer NOT NULL,
    treatment_id integer,
    updated_by_id integer
);


--
-- Name: content_library_sendtimepersonalizationvariant_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_sendtimepersonalizationvariant_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_sendtimepersonalizationvariant_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_sendtimepersonalizationvariant_id_seq OWNED BY public.content_library_sendtimepersonalizationvariant.id;


--
-- Name: content_library_session; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_session (
    session_key character varying(40) NOT NULL,
    session_data text NOT NULL,
    expire_date timestamp with time zone NOT NULL,
    client_id integer
);


--
-- Name: content_library_slice; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_slice (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    alt_text character varying(1000) NOT NULL,
    title_text character varying(1000) NOT NULL,
    client_id integer NOT NULL,
    created_by_id integer,
    layout_id integer NOT NULL,
    updated_by_id integer,
    link_id integer,
    image_id integer
);


--
-- Name: content_library_slice_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_slice_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_slice_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_slice_id_seq OWNED BY public.content_library_slice.id;


--
-- Name: content_library_staticaudiencemetadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_staticaudiencemetadata (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    source_field_name character varying(255),
    destination_field_name character varying(255),
    data_type smallint NOT NULL,
    nullable boolean NOT NULL,
    default_value character varying(255),
    constant boolean NOT NULL,
    mapped_values jsonb NOT NULL,
    filter_condition character varying(4000),
    audience_id integer NOT NULL,
    created_by_id integer,
    updated_by_id integer,
    null_values character varying(10)[] NOT NULL,
    "position" integer NOT NULL,
    datetime_format character varying(30),
    CONSTRAINT content_library_staticaudiencemetadata_position_check CHECK (("position" >= 0))
);


--
-- Name: content_library_staticaudiencemetadata_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_staticaudiencemetadata_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_staticaudiencemetadata_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_staticaudiencemetadata_id_seq OWNED BY public.content_library_staticaudiencemetadata.id;


--
-- Name: content_library_subjectline; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_subjectline (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    text character varying(255) NOT NULL,
    uuid uuid NOT NULL,
    short_uuid character varying(7) NOT NULL,
    "order" integer NOT NULL,
    created_by_id integer,
    creative_id integer NOT NULL,
    updated_by_id integer,
    CONSTRAINT content_library_subjectline_order_check CHECK (("order" >= 0))
);


--
-- Name: content_library_subjectline_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_subjectline_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_subjectline_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_subjectline_id_seq OWNED BY public.content_library_subjectline.id;


--
-- Name: content_library_tag; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_tag (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    name character varying(200) NOT NULL,
    client_id integer NOT NULL,
    created_by_id integer,
    updated_by_id integer
);


--
-- Name: content_library_tag_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_tag_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_tag_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_tag_id_seq OWNED BY public.content_library_tag.id;


--
-- Name: content_library_template; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_template (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    title character varying(200) NOT NULL,
    uuid uuid NOT NULL,
    client_id integer NOT NULL,
    created_by_id integer,
    updated_by_id integer,
    short_uuid character varying(7) NOT NULL,
    body_id integer,
    archived boolean NOT NULL,
    use_for_bulk_proofs boolean NOT NULL
);


--
-- Name: content_library_template_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_template_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_template_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_template_id_seq OWNED BY public.content_library_template.id;


--
-- Name: content_library_templatecontentblock; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_templatecontentblock (
    id integer NOT NULL,
    "position" integer NOT NULL,
    content_block_id integer NOT NULL,
    template_id integer NOT NULL,
    is_primary boolean NOT NULL,
    CONSTRAINT content_library_templatecontentblock_position_check CHECK (("position" >= 0))
);


--
-- Name: content_library_templatecontentblock_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_templatecontentblock_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_templatecontentblock_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_templatecontentblock_id_seq OWNED BY public.content_library_templatecontentblock.id;


--
-- Name: content_library_templateexperiment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_templateexperiment (
    baseexperiment_ptr_id integer NOT NULL
);


--
-- Name: content_library_templatetag; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_templatetag (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    title character varying(200) NOT NULL,
    uuid uuid NOT NULL,
    "position" integer NOT NULL,
    slug character varying(30) NOT NULL,
    field_type smallint NOT NULL,
    client_id integer NOT NULL,
    created_by_id integer,
    updated_by_id integer,
    max_length integer,
    format_string character varying(255) NOT NULL,
    default_image_upload_type smallint NOT NULL,
    CONSTRAINT content_library_templatetag_position_check CHECK (("position" >= 0))
);


--
-- Name: content_library_templatetag_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_templatetag_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_templatetag_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_templatetag_id_seq OWNED BY public.content_library_templatetag.id;


--
-- Name: content_library_templatetagchoice; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_templatetagchoice (
    id integer NOT NULL,
    title character varying(200) NOT NULL,
    value character varying(200) NOT NULL,
    "position" integer NOT NULL,
    template_tag_id integer NOT NULL,
    CONSTRAINT content_library_templatetagchoice_position_check CHECK (("position" >= 0))
);


--
-- Name: content_library_templatetagchoice_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_templatetagchoice_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_templatetagchoice_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_templatetagchoice_id_seq OWNED BY public.content_library_templatetagchoice.id;


--
-- Name: content_library_templatetreatment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_templatetreatment (
    basetreatment_ptr_id integer NOT NULL,
    "order" smallint NOT NULL,
    experiment_id integer NOT NULL
);


--
-- Name: content_library_templatevariant; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_templatevariant (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    created_by_id integer,
    event_id integer NOT NULL,
    treatment_id integer,
    updated_by_id integer
);


--
-- Name: content_library_templatevariant_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_templatevariant_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_templatevariant_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_templatevariant_id_seq OWNED BY public.content_library_templatevariant.id;


--
-- Name: content_library_trackingparameter; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_trackingparameter (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    title character varying(200) NOT NULL,
    required boolean NOT NULL,
    slug character varying(30) NOT NULL,
    max_length integer,
    default_value character varying(255) NOT NULL,
    level smallint NOT NULL,
    client_id integer NOT NULL,
    created_by_id integer,
    updated_by_id integer,
    field_type smallint NOT NULL,
    "position" integer NOT NULL,
    CONSTRAINT content_library_trackingparameter_position_check CHECK (("position" >= 0))
);


--
-- Name: content_library_trackingparameter_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_trackingparameter_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_trackingparameter_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_trackingparameter_id_seq OWNED BY public.content_library_trackingparameter.id;


--
-- Name: content_library_trackingparameterchoice; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_trackingparameterchoice (
    id integer NOT NULL,
    title character varying(200) NOT NULL,
    value character varying(200) NOT NULL,
    "position" integer NOT NULL,
    tracking_parameter_id integer NOT NULL,
    CONSTRAINT content_library_trackingparameterchoice_position_check CHECK (("position" >= 0))
);


--
-- Name: content_library_trackingparameterchoice_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_trackingparameterchoice_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_trackingparameterchoice_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_trackingparameterchoice_id_seq OWNED BY public.content_library_trackingparameterchoice.id;


--
-- Name: content_library_user; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_user (
    id integer NOT NULL,
    password character varying(128) NOT NULL,
    last_login timestamp with time zone,
    is_superuser boolean NOT NULL,
    email character varying(255) NOT NULL,
    is_staff boolean NOT NULL,
    is_active boolean NOT NULL,
    date_joined timestamp with time zone NOT NULL,
    first_name character varying(255) NOT NULL,
    last_name character varying(255) NOT NULL
);


--
-- Name: content_library_user_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_user_groups (
    id integer NOT NULL,
    user_id integer NOT NULL,
    group_id integer NOT NULL
);


--
-- Name: content_library_user_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_user_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_user_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_user_groups_id_seq OWNED BY public.content_library_user_groups.id;


--
-- Name: content_library_user_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_user_id_seq OWNED BY public.content_library_user.id;


--
-- Name: content_library_user_user_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_library_user_user_permissions (
    id integer NOT NULL,
    user_id integer NOT NULL,
    permission_id integer NOT NULL
);


--
-- Name: content_library_user_user_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_library_user_user_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_library_user_user_permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_library_user_user_permissions_id_seq OWNED BY public.content_library_user_user_permissions.id;


--
-- Name: django_admin_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.django_admin_log (
    id integer NOT NULL,
    action_time timestamp with time zone NOT NULL,
    object_id text,
    object_repr character varying(200) NOT NULL,
    action_flag smallint NOT NULL,
    change_message text NOT NULL,
    content_type_id integer,
    user_id integer NOT NULL,
    CONSTRAINT django_admin_log_action_flag_check CHECK ((action_flag >= 0))
);


--
-- Name: django_admin_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.django_admin_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: django_admin_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.django_admin_log_id_seq OWNED BY public.django_admin_log.id;


--
-- Name: django_celery_beat_clockedschedule; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.django_celery_beat_clockedschedule (
    id integer NOT NULL,
    clocked_time timestamp with time zone NOT NULL,
    enabled boolean NOT NULL
);


--
-- Name: django_celery_beat_clockedschedule_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.django_celery_beat_clockedschedule_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: django_celery_beat_clockedschedule_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.django_celery_beat_clockedschedule_id_seq OWNED BY public.django_celery_beat_clockedschedule.id;


--
-- Name: django_celery_beat_crontabschedule; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.django_celery_beat_crontabschedule (
    id integer NOT NULL,
    minute character varying(240) NOT NULL,
    hour character varying(96) NOT NULL,
    day_of_week character varying(64) NOT NULL,
    day_of_month character varying(124) NOT NULL,
    month_of_year character varying(64) NOT NULL,
    timezone character varying(63) NOT NULL
);


--
-- Name: django_celery_beat_crontabschedule_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.django_celery_beat_crontabschedule_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: django_celery_beat_crontabschedule_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.django_celery_beat_crontabschedule_id_seq OWNED BY public.django_celery_beat_crontabschedule.id;


--
-- Name: django_celery_beat_intervalschedule; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.django_celery_beat_intervalschedule (
    id integer NOT NULL,
    every integer NOT NULL,
    period character varying(24) NOT NULL
);


--
-- Name: django_celery_beat_intervalschedule_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.django_celery_beat_intervalschedule_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: django_celery_beat_intervalschedule_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.django_celery_beat_intervalschedule_id_seq OWNED BY public.django_celery_beat_intervalschedule.id;


--
-- Name: django_celery_beat_periodictask; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.django_celery_beat_periodictask (
    id integer NOT NULL,
    name character varying(200) NOT NULL,
    task character varying(200) NOT NULL,
    args text NOT NULL,
    kwargs text NOT NULL,
    queue character varying(200),
    exchange character varying(200),
    routing_key character varying(200),
    expires timestamp with time zone,
    enabled boolean NOT NULL,
    last_run_at timestamp with time zone,
    total_run_count integer NOT NULL,
    date_changed timestamp with time zone NOT NULL,
    description text NOT NULL,
    crontab_id integer,
    interval_id integer,
    solar_id integer,
    one_off boolean NOT NULL,
    start_time timestamp with time zone,
    priority integer,
    headers text NOT NULL,
    clocked_id integer,
    expire_seconds integer,
    CONSTRAINT django_celery_beat_periodictask_expire_seconds_check CHECK ((expire_seconds >= 0)),
    CONSTRAINT django_celery_beat_periodictask_priority_check CHECK ((priority >= 0)),
    CONSTRAINT django_celery_beat_periodictask_total_run_count_check CHECK ((total_run_count >= 0))
);


--
-- Name: django_celery_beat_periodictask_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.django_celery_beat_periodictask_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: django_celery_beat_periodictask_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.django_celery_beat_periodictask_id_seq OWNED BY public.django_celery_beat_periodictask.id;


--
-- Name: django_celery_beat_periodictasks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.django_celery_beat_periodictasks (
    ident smallint NOT NULL,
    last_update timestamp with time zone NOT NULL
);


--
-- Name: django_celery_beat_solarschedule; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.django_celery_beat_solarschedule (
    id integer NOT NULL,
    event character varying(24) NOT NULL,
    latitude numeric(9,6) NOT NULL,
    longitude numeric(9,6) NOT NULL
);


--
-- Name: django_celery_beat_solarschedule_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.django_celery_beat_solarschedule_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: django_celery_beat_solarschedule_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.django_celery_beat_solarschedule_id_seq OWNED BY public.django_celery_beat_solarschedule.id;


--
-- Name: django_content_type; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.django_content_type (
    id integer NOT NULL,
    app_label character varying(100) NOT NULL,
    model character varying(100) NOT NULL
);


--
-- Name: django_content_type_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.django_content_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: django_content_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.django_content_type_id_seq OWNED BY public.django_content_type.id;


--
-- Name: django_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.django_migrations (
    id integer NOT NULL,
    app character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    applied timestamp with time zone NOT NULL
);


--
-- Name: django_migrations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.django_migrations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: django_migrations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.django_migrations_id_seq OWNED BY public.django_migrations.id;


--
-- Name: django_session; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.django_session (
    session_key character varying(40) NOT NULL,
    session_data text NOT NULL,
    expire_date timestamp with time zone NOT NULL
);


--
-- Name: django_site; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.django_site (
    id integer NOT NULL,
    domain character varying(100) NOT NULL,
    name character varying(50) NOT NULL
);


--
-- Name: django_site_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.django_site_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: django_site_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.django_site_id_seq OWNED BY public.django_site.id;


--
-- Name: oauth2_provider_accesstoken_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.oauth2_provider_accesstoken_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oauth2_provider_accesstoken; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oauth2_provider_accesstoken (
    id bigint DEFAULT nextval('public.oauth2_provider_accesstoken_id_seq'::regclass) NOT NULL,
    token character varying(255) NOT NULL,
    expires timestamp with time zone NOT NULL,
    scope text NOT NULL,
    application_id bigint,
    user_id integer,
    created timestamp with time zone NOT NULL,
    updated timestamp with time zone NOT NULL
);


--
-- Name: oauth2_provider_grant_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.oauth2_provider_grant_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oauth2_provider_grant; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oauth2_provider_grant (
    id bigint DEFAULT nextval('public.oauth2_provider_grant_id_seq'::regclass) NOT NULL,
    code character varying(255) NOT NULL,
    expires timestamp with time zone NOT NULL,
    redirect_uri character varying(255) NOT NULL,
    scope text NOT NULL,
    application_id bigint NOT NULL,
    user_id integer NOT NULL,
    created timestamp with time zone NOT NULL,
    updated timestamp with time zone NOT NULL
);


--
-- Name: oauth2_provider_refreshtoken_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.oauth2_provider_refreshtoken_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oauth2_provider_refreshtoken; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oauth2_provider_refreshtoken (
    id bigint DEFAULT nextval('public.oauth2_provider_refreshtoken_id_seq'::regclass) NOT NULL,
    token character varying(255) NOT NULL,
    access_token_id bigint NOT NULL,
    application_id bigint NOT NULL,
    user_id integer NOT NULL,
    created timestamp with time zone NOT NULL,
    updated timestamp with time zone NOT NULL
);


--
-- Name: organizations_organization; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organizations_organization (
    id integer NOT NULL,
    name character varying(200) NOT NULL,
    is_active boolean NOT NULL,
    created timestamp with time zone NOT NULL,
    modified timestamp with time zone NOT NULL,
    slug character varying(200) NOT NULL
);


--
-- Name: organizations_organization_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.organizations_organization_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: organizations_organization_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.organizations_organization_id_seq OWNED BY public.organizations_organization.id;


--
-- Name: organizations_organizationowner; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organizations_organizationowner (
    id integer NOT NULL,
    created timestamp with time zone NOT NULL,
    modified timestamp with time zone NOT NULL,
    organization_id integer NOT NULL,
    organization_user_id integer NOT NULL
);


--
-- Name: organizations_organizationowner_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.organizations_organizationowner_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: organizations_organizationowner_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.organizations_organizationowner_id_seq OWNED BY public.organizations_organizationowner.id;


--
-- Name: organizations_organizationuser; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organizations_organizationuser (
    id integer NOT NULL,
    created timestamp with time zone NOT NULL,
    modified timestamp with time zone NOT NULL,
    is_admin boolean NOT NULL,
    organization_id integer NOT NULL,
    user_id integer NOT NULL
);


--
-- Name: organizations_organizationuser_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.organizations_organizationuser_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: organizations_organizationuser_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.organizations_organizationuser_id_seq OWNED BY public.organizations_organizationuser.id;


--
-- Name: prohibited_creatives_view; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.prohibited_creatives_view AS
 SELECT prohibited_creatives.creative_id,
    prohibited_creatives.prohibited_creative_id
   FROM ( SELECT content_library_creative_prohibited_creatives.from_creative_id AS creative_id,
            content_library_creative_prohibited_creatives.to_creative_id AS prohibited_creative_id
           FROM public.content_library_creative_prohibited_creatives) prohibited_creatives
UNION
 SELECT prohibited_creatives_by_tags.creative_id,
    prohibited_creatives_by_tags.prohihbited_creative_id AS prohibited_creative_id
   FROM ( SELECT pct.creative_id,
            ct.creative_id AS prohihbited_creative_id
           FROM (public.content_library_prohibitedcreativetag pct
             LEFT JOIN public.content_library_creative_tags ct ON ((pct.tag_id = ct.tag_id)))) prohibited_creatives_by_tags
UNION
 SELECT prohibited_creatives_by_product_collections.creative_id,
    prohibited_creatives_by_product_collections.prohibited_creative_id
   FROM ( WITH creative_product_values AS (
                 SELECT cpc.creative_id,
                    pcpv_1.productvalue_id
                   FROM (public.content_library_creative_product_collections cpc
                     LEFT JOIN public.content_library_productcollection_product_values pcpv_1 ON ((cpc.productcollection_id = pcpv_1.productcollection_id)))
                )
         SELECT DISTINCT pcpc.creative_id,
            cpv.creative_id AS prohibited_creative_id
           FROM ((public.content_library_prohibitedcreativeproductcollection pcpc
             LEFT JOIN public.content_library_productcollection_product_values pcpv ON ((pcpc.productcollection_id = pcpv.productcollection_id)))
             LEFT JOIN creative_product_values cpv ON ((cpv.productvalue_id = pcpv.productvalue_id)))) prohibited_creatives_by_product_collections;


--
-- Name: account_emailaddress id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_emailaddress ALTER COLUMN id SET DEFAULT nextval('public.account_emailaddress_id_seq'::regclass);


--
-- Name: account_emailconfirmation id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_emailconfirmation ALTER COLUMN id SET DEFAULT nextval('public.account_emailconfirmation_id_seq'::regclass);


--
-- Name: auth_group id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_group ALTER COLUMN id SET DEFAULT nextval('public.auth_group_id_seq'::regclass);


--
-- Name: auth_group_permissions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_group_permissions ALTER COLUMN id SET DEFAULT nextval('public.auth_group_permissions_id_seq'::regclass);


--
-- Name: auth_permission id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_permission ALTER COLUMN id SET DEFAULT nextval('public.auth_permission_id_seq'::regclass);


--
-- Name: content_library_acousticcampaigndynamiccontent id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_acousticcampaigndynamiccontent ALTER COLUMN id SET DEFAULT nextval('public.content_library_acousticcampaigndynamiccontent_id_seq'::regclass);


--
-- Name: content_library_acousticcampaignfromaddress id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_acousticcampaignfromaddress ALTER COLUMN id SET DEFAULT nextval('public.content_library_acousticcampaignfromaddress_id_seq'::regclass);


--
-- Name: content_library_acousticcampaignfromname id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_acousticcampaignfromname ALTER COLUMN id SET DEFAULT nextval('public.content_library_acousticcampaignfromname_id_seq'::regclass);


--
-- Name: content_library_acousticcampaignlinkmetadata id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_acousticcampaignlinkmetadata ALTER COLUMN id SET DEFAULT nextval('public.content_library_acousticcampaignlinkmetadata_id_seq'::regclass);


--
-- Name: content_library_acousticcampaignmailing id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_acousticcampaignmailing ALTER COLUMN id SET DEFAULT nextval('public.content_library_acousticcampaignmailing_id_seq'::regclass);


--
-- Name: content_library_acousticcampaignreplyto id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_acousticcampaignreplyto ALTER COLUMN id SET DEFAULT nextval('public.content_library_acousticcampaignreplyto_id_seq'::regclass);


--
-- Name: content_library_adhocvariant id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_adhocvariant ALTER COLUMN id SET DEFAULT nextval('public.content_library_adhocvariant_id_seq'::regclass);


--
-- Name: content_library_adhocvariant_treatments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_adhocvariant_treatments ALTER COLUMN id SET DEFAULT nextval('public.content_library_adhocvariant_treatments_id_seq'::regclass);


--
-- Name: content_library_adobecampaigneventmetadata id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_adobecampaigneventmetadata ALTER COLUMN id SET DEFAULT nextval('public.content_library_adobecampaigneventmetadata_id_seq'::regclass);


--
-- Name: content_library_application id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_application ALTER COLUMN id SET DEFAULT nextval('public.content_library_application_id_seq'::regclass);


--
-- Name: content_library_audience id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_audience ALTER COLUMN id SET DEFAULT nextval('public.content_library_audiencefilter_id_seq'::regclass);


--
-- Name: content_library_availability id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_availability ALTER COLUMN id SET DEFAULT nextval('public.content_library_availability_id_seq'::regclass);


--
-- Name: content_library_availableproductcollection id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_availableproductcollection ALTER COLUMN id SET DEFAULT nextval('public.content_library_availableproductcollection_id_seq'::regclass);


--
-- Name: content_library_availableproductcollection_product_values id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_availableproductcollection_product_values ALTER COLUMN id SET DEFAULT nextval('public.content_library_availableproductcollection_product_value_id_seq'::regclass);


--
-- Name: content_library_baseexperiment id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_baseexperiment ALTER COLUMN id SET DEFAULT nextval('public.content_library_baseexperiment_id_seq'::regclass);


--
-- Name: content_library_basetemplate id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_basetemplate ALTER COLUMN id SET DEFAULT nextval('public.content_library_basetemplate_id_seq'::regclass);


--
-- Name: content_library_basetreatment id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_basetreatment ALTER COLUMN id SET DEFAULT nextval('public.content_library_basetreatment_id_seq'::regclass);


--
-- Name: content_library_bodytemplate id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_bodytemplate ALTER COLUMN id SET DEFAULT nextval('public.content_library_bodytemplate_id_seq'::regclass);


--
-- Name: content_library_bodytemplatecontentblock id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_bodytemplatecontentblock ALTER COLUMN id SET DEFAULT nextval('public.content_library_bodytemplatecontentblock_id_seq'::regclass);


--
-- Name: content_library_cheetahdigitalclientconfig id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitalclientconfig ALTER COLUMN id SET DEFAULT nextval('public.content_library_cheetahdigitalclientconfig_id_seq'::regclass);


--
-- Name: content_library_cheetahdigitalcreativecontentblockdocument id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitalcreativecontentblockdocument ALTER COLUMN id SET DEFAULT nextval('public.content_library_cheetahdigitalcreativecontentblockdocume_id_seq'::regclass);


--
-- Name: content_library_cheetahdigitalcreativediscountofferdocument id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitalcreativediscountofferdocument ALTER COLUMN id SET DEFAULT nextval('public.content_library_cheetahdigitalcreativepromotiondocument_id_seq'::regclass);


--
-- Name: content_library_cheetahdigitalcreativedocument id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitalcreativedocument ALTER COLUMN id SET DEFAULT nextval('public.content_library_cheetahdigitalcreativedocument_id_seq'::regclass);


--
-- Name: content_library_cheetahdigitaleventmetadata id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitaleventmetadata ALTER COLUMN id SET DEFAULT nextval('public.content_library_cheetahdigitaleventmetadata_id_seq'::regclass);


--
-- Name: content_library_cheetahdigitallinkmetadata id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitallinkmetadata ALTER COLUMN id SET DEFAULT nextval('public.content_library_cheetahdigitallinkmetadata_id_seq'::regclass);


--
-- Name: content_library_cheetahdigitalstaticcontentblockdocument id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitalstaticcontentblockdocument ALTER COLUMN id SET DEFAULT nextval('public.content_library_cheetahdigitalstaticcontentblockdocument_id_seq'::regclass);


--
-- Name: content_library_client id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_client ALTER COLUMN id SET DEFAULT nextval('public.content_library_client_id_seq'::regclass);


--
-- Name: content_library_clientconfiguration id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_clientconfiguration ALTER COLUMN id SET DEFAULT nextval('public.content_library_clientconfiguration_id_seq'::regclass);


--
-- Name: content_library_clientreuserule id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_clientreuserule ALTER COLUMN id SET DEFAULT nextval('public.content_library_clientreuserule_id_seq'::regclass);


--
-- Name: content_library_clientuser id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_clientuser ALTER COLUMN id SET DEFAULT nextval('public.content_library_clientuser_id_seq'::regclass);


--
-- Name: content_library_clientuseradmin id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_clientuseradmin ALTER COLUMN id SET DEFAULT nextval('public.content_library_clientuseradmin_id_seq'::regclass);


--
-- Name: content_library_contentblock id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentblock ALTER COLUMN id SET DEFAULT nextval('public.content_library_contentblock_id_seq'::regclass);


--
-- Name: content_library_contentblockcreativeversion id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentblockcreativeversion ALTER COLUMN id SET DEFAULT nextval('public.content_library_contentblockcreativeversion_id_seq'::regclass);


--
-- Name: content_library_contentblocktemplatetag id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentblocktemplatetag ALTER COLUMN id SET DEFAULT nextval('public.content_library_contentblocktemplatetag_id_seq'::regclass);


--
-- Name: content_library_contentpersonalizationmodel id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentpersonalizationmodel ALTER COLUMN id SET DEFAULT nextval('public.content_library_recommendationsversion_id_seq'::regclass);


--
-- Name: content_library_contentpersonalizationmodelvariant id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentpersonalizationmodelvariant ALTER COLUMN id SET DEFAULT nextval('public.content_library_contentpersonalizationmodelvariant_id_seq'::regclass);


--
-- Name: content_library_creative id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creative ALTER COLUMN id SET DEFAULT nextval('public.content_library_creative_id_seq'::regclass);


--
-- Name: content_library_creative_product_collections id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creative_product_collections ALTER COLUMN id SET DEFAULT nextval('public.content_library_creative_product_collections_id_seq'::regclass);


--
-- Name: content_library_creative_prohibited_creatives id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creative_prohibited_creatives ALTER COLUMN id SET DEFAULT nextval('public.content_library_creative_prohibited_creatives_id_seq'::regclass);


--
-- Name: content_library_creative_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creative_tags ALTER COLUMN id SET DEFAULT nextval('public.content_library_creative_tags_id_seq'::regclass);


--
-- Name: content_library_creativeattribute id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creativeattribute ALTER COLUMN id SET DEFAULT nextval('public.content_library_creativeattribute_id_seq'::regclass);


--
-- Name: content_library_creativeattributechoice id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creativeattributechoice ALTER COLUMN id SET DEFAULT nextval('public.content_library_creativeattributechoice_id_seq'::regclass);


--
-- Name: content_library_creativecontentblockdocument id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creativecontentblockdocument ALTER COLUMN id SET DEFAULT nextval('public.content_library_creativecontentblockdocument_id_seq'::regclass);


--
-- Name: content_library_creativepromotion id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creativepromotion ALTER COLUMN id SET DEFAULT nextval('public.content_library_creativepromotion_id_seq'::regclass);


--
-- Name: content_library_creativereuserule id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creativereuserule ALTER COLUMN id SET DEFAULT nextval('public.content_library_creativereuserule_id_seq'::regclass);


--
-- Name: content_library_creativestats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creativestats ALTER COLUMN id SET DEFAULT nextval('public.content_library_creativestats_id_seq'::regclass);


--
-- Name: content_library_discountoffer id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_discountoffer ALTER COLUMN id SET DEFAULT nextval('public.content_library_discountoffer_id_seq'::regclass);


--
-- Name: content_library_document id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_document ALTER COLUMN id SET DEFAULT nextval('public.content_library_document_id_seq'::regclass);


--
-- Name: content_library_dynamicsectionvariant id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_dynamicsectionvariant ALTER COLUMN id SET DEFAULT nextval('public.content_library_dynamicsectionvariant_id_seq'::regclass);


--
-- Name: content_library_eligiblecreativesvariant id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eligiblecreativesvariant ALTER COLUMN id SET DEFAULT nextval('public.content_library_eligiblecreativesvariant_id_seq'::regclass);


--
-- Name: content_library_eligiblecreativesvariant_treatments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eligiblecreativesvariant_treatments ALTER COLUMN id SET DEFAULT nextval('public.content_library_eligiblecreativesvariant_treatments_id_seq'::regclass);


--
-- Name: content_library_emailserviceprovider id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_emailserviceprovider ALTER COLUMN id SET DEFAULT nextval('public.content_library_emailserviceprovider_id_seq'::regclass);


--
-- Name: content_library_event id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_event ALTER COLUMN id SET DEFAULT nextval('public.content_library_event_id_seq'::regclass);


--
-- Name: content_library_event_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_event_tags ALTER COLUMN id SET DEFAULT nextval('public.content_library_event_tags_id_seq'::regclass);


--
-- Name: content_library_eventacousticcampaignconfig id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventacousticcampaignconfig ALTER COLUMN id SET DEFAULT nextval('public.content_library_eventacousticcampaignconfig_id_seq'::regclass);


--
-- Name: content_library_eventattribute id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventattribute ALTER COLUMN id SET DEFAULT nextval('public.content_library_eventattribute_id_seq'::regclass);


--
-- Name: content_library_eventattributecheetahdigitaloptionid id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventattributecheetahdigitaloptionid ALTER COLUMN id SET DEFAULT nextval('public.content_library_eventattributecheetahdigitaloptionid_id_seq'::regclass);


--
-- Name: content_library_eventattributechoice id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventattributechoice ALTER COLUMN id SET DEFAULT nextval('public.content_library_eventattributechoice_id_seq'::regclass);


--
-- Name: content_library_eventattributechoicecheetahdigitalselectionid id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventattributechoicecheetahdigitalselectionid ALTER COLUMN id SET DEFAULT nextval('public.content_library_eventattributechoicecheetahdigitalselect_id_seq'::regclass);


--
-- Name: content_library_eventattributeoracleresponsyscampaignvariable id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventattributeoracleresponsyscampaignvariable ALTER COLUMN id SET DEFAULT nextval('public.content_library_eventattributeoracleresponsyscampaignvar_id_seq'::regclass);


--
-- Name: content_library_eventaudience id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventaudience ALTER COLUMN id SET DEFAULT nextval('public.content_library_eventaudiencefilter_id_seq'::regclass);


--
-- Name: content_library_eventcontentblockcreativestats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventcontentblockcreativestats ALTER COLUMN id SET DEFAULT nextval('public.content_library_eventcontentblockcreativestats_id_seq'::regclass);


--
-- Name: content_library_eventcontentblockstats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventcontentblockstats ALTER COLUMN id SET DEFAULT nextval('public.content_library_eventcontentblockstats_id_seq'::regclass);


--
-- Name: content_library_eventcreativestats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventcreativestats ALTER COLUMN id SET DEFAULT nextval('public.content_library_eventcreativestats_id_seq'::regclass);


--
-- Name: content_library_eventexperimentstats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventexperimentstats ALTER COLUMN id SET DEFAULT nextval('public.content_library_eventexperimentstats_id_seq'::regclass);


--
-- Name: content_library_eventoracleresponsysconfig id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventoracleresponsysconfig ALTER COLUMN id SET DEFAULT nextval('public.content_library_eventoracleresponsysconfig_id_seq'::regclass);


--
-- Name: content_library_eventoracleresponsysconfig_additional_data_13a0 id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventoracleresponsysconfig_additional_data_13a0 ALTER COLUMN id SET DEFAULT nextval('public.content_library_eventoracleresponsysconfig_additional_da_id_seq'::regclass);


--
-- Name: content_library_eventoracleresponsysconfig_suppressions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventoracleresponsysconfig_suppressions ALTER COLUMN id SET DEFAULT nextval('public.content_library_eventoracleresponsysconfig_suppressions_id_seq'::regclass);


--
-- Name: content_library_eventrun id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventrun ALTER COLUMN id SET DEFAULT nextval('public.content_library_eventrun_id_seq'::regclass);


--
-- Name: content_library_eventsalesforcemarketingcloudconfig id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventsalesforcemarketingcloudconfig ALTER COLUMN id SET DEFAULT nextval('public.content_library_eventsalesforcemarketingcloudconfig_id_seq'::regclass);


--
-- Name: content_library_eventsalesforcemarketingcloudconfig_suppresa376 id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventsalesforcemarketingcloudconfig_suppresa376 ALTER COLUMN id SET DEFAULT nextval('public.content_library_eventsalesforcemarketingcloudconfig_supp_id_seq'::regclass);


--
-- Name: content_library_eventstats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventstats ALTER COLUMN id SET DEFAULT nextval('public.content_library_eventstats_id_seq'::regclass);


--
-- Name: content_library_eventstatus id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventstatus ALTER COLUMN id SET DEFAULT nextval('public.content_library_eventstatus_id_seq'::regclass);


--
-- Name: content_library_eventtasklog id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventtasklog ALTER COLUMN id SET DEFAULT nextval('public.content_library_eventtasklog_id_seq'::regclass);


--
-- Name: content_library_eventtrackingpixel id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventtrackingpixel ALTER COLUMN id SET DEFAULT nextval('public.content_library_eventtrackingpixel_id_seq'::regclass);


--
-- Name: content_library_footertemplate id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_footertemplate ALTER COLUMN id SET DEFAULT nextval('public.content_library_footertemplate_id_seq'::regclass);


--
-- Name: content_library_footertemplatecontentblock id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_footertemplatecontentblock ALTER COLUMN id SET DEFAULT nextval('public.content_library_footertemplatecontentblock_id_seq'::regclass);


--
-- Name: content_library_freegift id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_freegift ALTER COLUMN id SET DEFAULT nextval('public.content_library_freegift_id_seq'::regclass);


--
-- Name: content_library_headertemplate id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_headertemplate ALTER COLUMN id SET DEFAULT nextval('public.content_library_headertemplate_id_seq'::regclass);


--
-- Name: content_library_headertemplatecontentblock id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_headertemplatecontentblock ALTER COLUMN id SET DEFAULT nextval('public.content_library_headertemplatecontentblock_id_seq'::regclass);


--
-- Name: content_library_htmlbundle id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_htmlbundle ALTER COLUMN id SET DEFAULT nextval('public.content_library_htmlbundle_id_seq'::regclass);


--
-- Name: content_library_htmlbundleimage id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_htmlbundleimage ALTER COLUMN id SET DEFAULT nextval('public.content_library_htmlbundleimage_id_seq'::regclass);


--
-- Name: content_library_htmlbundlelink id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_htmlbundlelink ALTER COLUMN id SET DEFAULT nextval('public.content_library_htmlbundlelink_id_seq'::regclass);


--
-- Name: content_library_image id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_image ALTER COLUMN id SET DEFAULT nextval('public.content_library_image_id_seq'::regclass);


--
-- Name: content_library_imagelayout id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_imagelayout ALTER COLUMN id SET DEFAULT nextval('public.content_library_imagelayout_id_seq'::regclass);


--
-- Name: content_library_imageslice id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_imageslice ALTER COLUMN id SET DEFAULT nextval('public.content_library_imageslice_id_seq'::regclass);


--
-- Name: content_library_inboxpreview id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_inboxpreview ALTER COLUMN id SET DEFAULT nextval('public.content_library_inboxpreview_id_seq'::regclass);


--
-- Name: content_library_invitation id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_invitation ALTER COLUMN id SET DEFAULT nextval('public.content_library_invitation_id_seq'::regclass);


--
-- Name: content_library_layout id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_layout ALTER COLUMN id SET DEFAULT nextval('public.content_library_layout_id_seq'::regclass);


--
-- Name: content_library_link id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_link ALTER COLUMN id SET DEFAULT nextval('public.content_library_newlink_id_seq'::regclass);


--
-- Name: content_library_linkcategory id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_linkcategory ALTER COLUMN id SET DEFAULT nextval('public.content_library_linkcategory_id_seq'::regclass);


--
-- Name: content_library_linkgroup id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_linkgroup ALTER COLUMN id SET DEFAULT nextval('public.content_library_linkgroup_id_seq'::regclass);


--
-- Name: content_library_movableinkcreative id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_movableinkcreative ALTER COLUMN id SET DEFAULT nextval('public.content_library_movableinkcreative_id_seq'::regclass);


--
-- Name: content_library_movableinkintegration id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_movableinkintegration ALTER COLUMN id SET DEFAULT nextval('public.content_library_movableinkintegration_id_seq'::regclass);


--
-- Name: content_library_neweligiblecreative id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_neweligiblecreative ALTER COLUMN id SET DEFAULT nextval('public.content_library_neweligiblecreative_id_seq1'::regclass);


--
-- Name: content_library_neworacleresponsysclientconfig id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_neworacleresponsysclientconfig ALTER COLUMN id SET DEFAULT nextval('public.content_library_neworacleresponsysclientconfig_id_seq'::regclass);


--
-- Name: content_library_offer id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_offer ALTER COLUMN id SET DEFAULT nextval('public.content_library_offer_id_seq'::regclass);


--
-- Name: content_library_oracleresponsysadditionaldatasource id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsysadditionaldatasource ALTER COLUMN id SET DEFAULT nextval('public.content_library_oracleresponsysadditionaldatasource_id_seq'::regclass);


--
-- Name: content_library_oracleresponsyscampaignvariable id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyscampaignvariable ALTER COLUMN id SET DEFAULT nextval('public.content_library_oracleresponsyscampaignvariable_id_seq'::regclass);


--
-- Name: content_library_oracleresponsyscampaignvariablechoice id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyscampaignvariablechoice ALTER COLUMN id SET DEFAULT nextval('public.content_library_oracleresponsyscampaignvariablechoice_id_seq'::regclass);


--
-- Name: content_library_oracleresponsysclientconfig id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsysclientconfig ALTER COLUMN id SET DEFAULT nextval('public.content_library_oracleresponsysclientconfig_id_seq'::regclass);


--
-- Name: content_library_oracleresponsyscreativecontentblockdocument id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyscreativecontentblockdocument ALTER COLUMN id SET DEFAULT nextval('public.content_library_oracleresponsyscreativecontentblockdocum_id_seq'::regclass);


--
-- Name: content_library_oracleresponsyscreativediscountofferdocument id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyscreativediscountofferdocument ALTER COLUMN id SET DEFAULT nextval('public.content_library_oracleresponsyscreativepromotiondocument_id_seq'::regclass);


--
-- Name: content_library_oracleresponsyscreativedocument id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyscreativedocument ALTER COLUMN id SET DEFAULT nextval('public.content_library_oracleresponsyscreativedocument_id_seq'::regclass);


--
-- Name: content_library_oracleresponsyslaunch id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyslaunch ALTER COLUMN id SET DEFAULT nextval('public.content_library_oracleresponsyseventmetadata_id_seq'::regclass);


--
-- Name: content_library_oracleresponsyslinkmetadata id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyslinkmetadata ALTER COLUMN id SET DEFAULT nextval('public.content_library_oracleresponsyslinkmetadata_id_seq'::regclass);


--
-- Name: content_library_oracleresponsyslist id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyslist ALTER COLUMN id SET DEFAULT nextval('public.content_library_oracleresponsyslist_id_seq'::regclass);


--
-- Name: content_library_oracleresponsysmarketingprogram id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsysmarketingprogram ALTER COLUMN id SET DEFAULT nextval('public.content_library_oracleresponsysmarketingprogram_id_seq'::regclass);


--
-- Name: content_library_oracleresponsysmarketingstrategy id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsysmarketingstrategy ALTER COLUMN id SET DEFAULT nextval('public.content_library_oracleresponsysmarketingstrategy_id_seq'::regclass);


--
-- Name: content_library_oracleresponsyssenderprofile id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyssenderprofile ALTER COLUMN id SET DEFAULT nextval('public.content_library_oracleresponsyssenderprofile_id_seq'::regclass);


--
-- Name: content_library_oracleresponsysstaticcontentblockdocument id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsysstaticcontentblockdocument ALTER COLUMN id SET DEFAULT nextval('public.content_library_oracleresponsysstaticcontentblockdocumen_id_seq'::regclass);


--
-- Name: content_library_oracleresponsyssuppression id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyssuppression ALTER COLUMN id SET DEFAULT nextval('public.content_library_oracleresponsyssuppression_id_seq'::regclass);


--
-- Name: content_library_persadocampaign id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_persadocampaign ALTER COLUMN id SET DEFAULT nextval('public.content_library_persadocampaign_id_seq'::regclass);


--
-- Name: content_library_predefinedlayoutstructure id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_predefinedlayoutstructure ALTER COLUMN id SET DEFAULT nextval('public.content_library_predefinedlayoutstructure_id_seq'::regclass);


--
-- Name: content_library_productcollection id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_productcollection ALTER COLUMN id SET DEFAULT nextval('public.content_library_productcollection_id_seq'::regclass);


--
-- Name: content_library_productcollection_product_values id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_productcollection_product_values ALTER COLUMN id SET DEFAULT nextval('public.content_library_productcollection_product_values_id_seq'::regclass);


--
-- Name: content_library_productfield id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_productfield ALTER COLUMN id SET DEFAULT nextval('public.content_library_productfield_id_seq'::regclass);


--
-- Name: content_library_productvalue id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_productvalue ALTER COLUMN id SET DEFAULT nextval('public.content_library_productvalue_id_seq'::regclass);


--
-- Name: content_library_prohibitedcreativeproductcollection id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_prohibitedcreativeproductcollection ALTER COLUMN id SET DEFAULT nextval('public.content_library_prohibitedcreativeproductcollection_id_seq'::regclass);


--
-- Name: content_library_prohibitedcreativetag id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_prohibitedcreativetag ALTER COLUMN id SET DEFAULT nextval('public.content_library_prohibitedcreativetag_id_seq'::regclass);


--
-- Name: content_library_promotion id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_promotion ALTER COLUMN id SET DEFAULT nextval('public.content_library_promotion_id_seq'::regclass);


--
-- Name: content_library_promotionoffer id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_promotionoffer ALTER COLUMN id SET DEFAULT nextval('public.content_library_promotionoffer_id_seq'::regclass);


--
-- Name: content_library_promotionredemption id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_promotionredemption ALTER COLUMN id SET DEFAULT nextval('public.content_library_promotionredemption_id_seq'::regclass);


--
-- Name: content_library_proxycontrolvariant id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_proxycontrolvariant ALTER COLUMN id SET DEFAULT nextval('public.content_library_proxycontrolvariant_id_seq'::regclass);


--
-- Name: content_library_quantitydiscount id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_quantitydiscount ALTER COLUMN id SET DEFAULT nextval('public.content_library_quantitydiscount_id_seq'::regclass);


--
-- Name: content_library_querystringparameter id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_querystringparameter ALTER COLUMN id SET DEFAULT nextval('public.content_library_querystringparameter_id_seq'::regclass);


--
-- Name: content_library_recommendationrun id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_recommendationrun ALTER COLUMN id SET DEFAULT nextval('public.content_library_recommendationrun_id_seq'::regclass);


--
-- Name: content_library_recommendationrun_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_recommendationrun_events ALTER COLUMN id SET DEFAULT nextval('public.content_library_recommendationrun_events_id_seq'::regclass);


--
-- Name: content_library_recommendationrunlog id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_recommendationrunlog ALTER COLUMN id SET DEFAULT nextval('public.content_library_recommendationrunlog_id_seq'::regclass);


--
-- Name: content_library_renderedcreative id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_renderedcreative ALTER COLUMN id SET DEFAULT nextval('public.content_library_renderedcreative_id_seq'::regclass);


--
-- Name: content_library_rewardsmultiplier id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_rewardsmultiplier ALTER COLUMN id SET DEFAULT nextval('public.content_library_rewardsmultiplier_id_seq'::regclass);


--
-- Name: content_library_salesforcemarketingcloudcreativecontentblocaf9f id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudcreativecontentblocaf9f ALTER COLUMN id SET DEFAULT nextval('public.content_library_salesforcemarketingcloudcreativecontentb_id_seq'::regclass);


--
-- Name: content_library_salesforcemarketingcloudcreativediscountoff3b11 id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudcreativediscountoff3b11 ALTER COLUMN id SET DEFAULT nextval('public.content_library_salesforcemarketingcloudcreativepromotio_id_seq'::regclass);


--
-- Name: content_library_salesforcemarketingcloudcreativedocument id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudcreativedocument ALTER COLUMN id SET DEFAULT nextval('public.content_library_salesforcemarketingcloudcreativedocument_id_seq'::regclass);


--
-- Name: content_library_salesforcemarketingcloudintegration id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudintegration ALTER COLUMN id SET DEFAULT nextval('public.content_library_salesforcemarketingcloudintegration_id_seq'::regclass);


--
-- Name: content_library_salesforcemarketingcloudlinkmetadata id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudlinkmetadata ALTER COLUMN id SET DEFAULT nextval('public.content_library_salesforcemarketingcloudlinkmetadata_id_seq'::regclass);


--
-- Name: content_library_salesforcemarketingcloudmessagedeliveryconfig id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudmessagedeliveryconfig ALTER COLUMN id SET DEFAULT nextval('public.content_library_salesforcemarketingcloudmessagedeliveryc_id_seq'::regclass);


--
-- Name: content_library_salesforcemarketingcloudpublicationlist id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudpublicationlist ALTER COLUMN id SET DEFAULT nextval('public.content_library_salesforcemarketingcloudpublicationlist_id_seq'::regclass);


--
-- Name: content_library_salesforcemarketingcloudsend id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudsend ALTER COLUMN id SET DEFAULT nextval('public.content_library_salesforcemarketingcloudeventmetadata_id_seq'::regclass);


--
-- Name: content_library_salesforcemarketingcloudsenderprofile id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudsenderprofile ALTER COLUMN id SET DEFAULT nextval('public.content_library_salesforcemarketingcloudsenderprofile_id_seq'::regclass);


--
-- Name: content_library_salesforcemarketingcloudstaticcontentblockda7ea id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudstaticcontentblockda7ea ALTER COLUMN id SET DEFAULT nextval('public.content_library_salesforcemarketingcloudstaticcontentblo_id_seq'::regclass);


--
-- Name: content_library_salesforcemarketingcloudsuppressiondataexte91a1 id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudsuppressiondataexte91a1 ALTER COLUMN id SET DEFAULT nextval('public.content_library_salesforcemarketingcloudsuppressiondatae_id_seq'::regclass);


--
-- Name: content_library_section id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_section ALTER COLUMN id SET DEFAULT nextval('public.content_library_section_id_seq'::regclass);


--
-- Name: content_library_senddatetime id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_senddatetime ALTER COLUMN id SET DEFAULT nextval('public.content_library_newsenddatetime_id_seq'::regclass);


--
-- Name: content_library_sendtimepersonalizationvariant id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_sendtimepersonalizationvariant ALTER COLUMN id SET DEFAULT nextval('public.content_library_sendtimepersonalizationvariant_id_seq'::regclass);


--
-- Name: content_library_slice id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_slice ALTER COLUMN id SET DEFAULT nextval('public.content_library_slice_id_seq'::regclass);


--
-- Name: content_library_staticaudiencemetadata id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_staticaudiencemetadata ALTER COLUMN id SET DEFAULT nextval('public.content_library_staticaudiencemetadata_id_seq'::regclass);


--
-- Name: content_library_subjectline id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_subjectline ALTER COLUMN id SET DEFAULT nextval('public.content_library_subjectline_id_seq'::regclass);


--
-- Name: content_library_tag id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_tag ALTER COLUMN id SET DEFAULT nextval('public.content_library_tag_id_seq'::regclass);


--
-- Name: content_library_template id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_template ALTER COLUMN id SET DEFAULT nextval('public.content_library_template_id_seq'::regclass);


--
-- Name: content_library_templatecontentblock id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_templatecontentblock ALTER COLUMN id SET DEFAULT nextval('public.content_library_templatecontentblock_id_seq'::regclass);


--
-- Name: content_library_templatetag id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_templatetag ALTER COLUMN id SET DEFAULT nextval('public.content_library_templatetag_id_seq'::regclass);


--
-- Name: content_library_templatetagchoice id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_templatetagchoice ALTER COLUMN id SET DEFAULT nextval('public.content_library_templatetagchoice_id_seq'::regclass);


--
-- Name: content_library_templatevariant id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_templatevariant ALTER COLUMN id SET DEFAULT nextval('public.content_library_templatevariant_id_seq'::regclass);


--
-- Name: content_library_trackingparameter id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_trackingparameter ALTER COLUMN id SET DEFAULT nextval('public.content_library_trackingparameter_id_seq'::regclass);


--
-- Name: content_library_trackingparameterchoice id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_trackingparameterchoice ALTER COLUMN id SET DEFAULT nextval('public.content_library_trackingparameterchoice_id_seq'::regclass);


--
-- Name: content_library_user id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_user ALTER COLUMN id SET DEFAULT nextval('public.content_library_user_id_seq'::regclass);


--
-- Name: content_library_user_groups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_user_groups ALTER COLUMN id SET DEFAULT nextval('public.content_library_user_groups_id_seq'::regclass);


--
-- Name: content_library_user_user_permissions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_user_user_permissions ALTER COLUMN id SET DEFAULT nextval('public.content_library_user_user_permissions_id_seq'::regclass);


--
-- Name: django_admin_log id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_admin_log ALTER COLUMN id SET DEFAULT nextval('public.django_admin_log_id_seq'::regclass);


--
-- Name: django_celery_beat_clockedschedule id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_celery_beat_clockedschedule ALTER COLUMN id SET DEFAULT nextval('public.django_celery_beat_clockedschedule_id_seq'::regclass);


--
-- Name: django_celery_beat_crontabschedule id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_celery_beat_crontabschedule ALTER COLUMN id SET DEFAULT nextval('public.django_celery_beat_crontabschedule_id_seq'::regclass);


--
-- Name: django_celery_beat_intervalschedule id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_celery_beat_intervalschedule ALTER COLUMN id SET DEFAULT nextval('public.django_celery_beat_intervalschedule_id_seq'::regclass);


--
-- Name: django_celery_beat_periodictask id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_celery_beat_periodictask ALTER COLUMN id SET DEFAULT nextval('public.django_celery_beat_periodictask_id_seq'::regclass);


--
-- Name: django_celery_beat_solarschedule id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_celery_beat_solarschedule ALTER COLUMN id SET DEFAULT nextval('public.django_celery_beat_solarschedule_id_seq'::regclass);


--
-- Name: django_content_type id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_content_type ALTER COLUMN id SET DEFAULT nextval('public.django_content_type_id_seq'::regclass);


--
-- Name: django_migrations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_migrations ALTER COLUMN id SET DEFAULT nextval('public.django_migrations_id_seq'::regclass);


--
-- Name: django_site id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_site ALTER COLUMN id SET DEFAULT nextval('public.django_site_id_seq'::regclass);


--
-- Name: organizations_organization id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations_organization ALTER COLUMN id SET DEFAULT nextval('public.organizations_organization_id_seq'::regclass);


--
-- Name: organizations_organizationowner id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations_organizationowner ALTER COLUMN id SET DEFAULT nextval('public.organizations_organizationowner_id_seq'::regclass);


--
-- Name: organizations_organizationuser id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations_organizationuser ALTER COLUMN id SET DEFAULT nextval('public.organizations_organizationuser_id_seq'::regclass);


--
-- Name: account_emailaddress account_emailaddress_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_emailaddress
    ADD CONSTRAINT account_emailaddress_email_key UNIQUE (email);


--
-- Name: account_emailaddress account_emailaddress_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_emailaddress
    ADD CONSTRAINT account_emailaddress_pkey PRIMARY KEY (id);


--
-- Name: account_emailconfirmation account_emailconfirmation_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_emailconfirmation
    ADD CONSTRAINT account_emailconfirmation_key_key UNIQUE (key);


--
-- Name: account_emailconfirmation account_emailconfirmation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_emailconfirmation
    ADD CONSTRAINT account_emailconfirmation_pkey PRIMARY KEY (id);


--
-- Name: auth_group auth_group_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_name_key UNIQUE (name);


--
-- Name: auth_group_permissions auth_group_permissions_group_id_permission_id_0cd325b0_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq UNIQUE (group_id, permission_id);


--
-- Name: auth_group_permissions auth_group_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_pkey PRIMARY KEY (id);


--
-- Name: auth_group auth_group_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_pkey PRIMARY KEY (id);


--
-- Name: auth_permission auth_permission_content_type_id_codename_01ab375a_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq UNIQUE (content_type_id, codename);


--
-- Name: auth_permission auth_permission_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_pkey PRIMARY KEY (id);


--
-- Name: content_library_acousticcampaign content_library_acousticcampaign_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_acousticcampaign
    ADD CONSTRAINT content_library_acousticcampaign_pkey PRIMARY KEY (emailserviceprovider_ptr_id);


--
-- Name: content_library_acousticcampaigndynamiccontent content_library_acousticcampaigndynamiccontent_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_acousticcampaigndynamiccontent
    ADD CONSTRAINT content_library_acousticcampaigndynamiccontent_pkey PRIMARY KEY (id);


--
-- Name: content_library_acousticcampaignfromaddress content_library_acousticcampaignfromaddress_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_acousticcampaignfromaddress
    ADD CONSTRAINT content_library_acousticcampaignfromaddress_pkey PRIMARY KEY (id);


--
-- Name: content_library_acousticcampaignfromname content_library_acousticcampaignfromname_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_acousticcampaignfromname
    ADD CONSTRAINT content_library_acousticcampaignfromname_pkey PRIMARY KEY (id);


--
-- Name: content_library_acousticcampaignlinkmetadata content_library_acousticcampaignlinkmetadata_link_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_acousticcampaignlinkmetadata
    ADD CONSTRAINT content_library_acousticcampaignlinkmetadata_link_id_key UNIQUE (link_id);


--
-- Name: content_library_acousticcampaignlinkmetadata content_library_acousticcampaignlinkmetadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_acousticcampaignlinkmetadata
    ADD CONSTRAINT content_library_acousticcampaignlinkmetadata_pkey PRIMARY KEY (id);


--
-- Name: content_library_acousticcampaignmailing content_library_acousticcampaignmailing_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_acousticcampaignmailing
    ADD CONSTRAINT content_library_acousticcampaignmailing_pkey PRIMARY KEY (id);


--
-- Name: content_library_acousticcampaignreplyto content_library_acousticcampaignreplyto_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_acousticcampaignreplyto
    ADD CONSTRAINT content_library_acousticcampaignreplyto_pkey PRIMARY KEY (id);


--
-- Name: content_library_adhocexperiment content_library_adhocexperiment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_adhocexperiment
    ADD CONSTRAINT content_library_adhocexperiment_pkey PRIMARY KEY (baseexperiment_ptr_id);


--
-- Name: content_library_adhoctreatment content_library_adhoctre_experiment_id_order_6622c5c1_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_adhoctreatment
    ADD CONSTRAINT content_library_adhoctre_experiment_id_order_6622c5c1_uniq UNIQUE (experiment_id, "order");


--
-- Name: content_library_adhoctreatment content_library_adhoctreatment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_adhoctreatment
    ADD CONSTRAINT content_library_adhoctreatment_pkey PRIMARY KEY (basetreatment_ptr_id);


--
-- Name: content_library_adhocvariant_treatments content_library_adhocvar_adhocvariant_id_adhoctre_77ececa2_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_adhocvariant_treatments
    ADD CONSTRAINT content_library_adhocvar_adhocvariant_id_adhoctre_77ececa2_uniq UNIQUE (adhocvariant_id, adhoctreatment_id);


--
-- Name: content_library_adhocvariant content_library_adhocvariant_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_adhocvariant
    ADD CONSTRAINT content_library_adhocvariant_pkey PRIMARY KEY (id);


--
-- Name: content_library_adhocvariant_treatments content_library_adhocvariant_treatments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_adhocvariant_treatments
    ADD CONSTRAINT content_library_adhocvariant_treatments_pkey PRIMARY KEY (id);


--
-- Name: content_library_adobecampaigneventmetadata content_library_adobecam_event_id_delivery_id_b62d4077_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_adobecampaigneventmetadata
    ADD CONSTRAINT content_library_adobecam_event_id_delivery_id_b62d4077_uniq UNIQUE (event_id, delivery_id);


--
-- Name: content_library_adobecampaigneventmetadata content_library_adobecampaigneventmetadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_adobecampaigneventmetadata
    ADD CONSTRAINT content_library_adobecampaigneventmetadata_pkey PRIMARY KEY (id);


--
-- Name: content_library_application content_library_application_client_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_application
    ADD CONSTRAINT content_library_application_client_id_key UNIQUE (client_id);


--
-- Name: content_library_application content_library_application_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_application
    ADD CONSTRAINT content_library_application_pkey PRIMARY KEY (id);


--
-- Name: content_library_audience content_library_audiencefilter_client_id_title_537c2ee1_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_audience
    ADD CONSTRAINT content_library_audiencefilter_client_id_title_537c2ee1_uniq UNIQUE (client_id, title);


--
-- Name: content_library_audience content_library_audiencefilter_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_audience
    ADD CONSTRAINT content_library_audiencefilter_pkey PRIMARY KEY (id);


--
-- Name: content_library_availability content_library_availability_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_availability
    ADD CONSTRAINT content_library_availability_pkey PRIMARY KEY (id);


--
-- Name: content_library_availableproductcollection_product_values content_library_availabl_availableproductcollecti_1ce63d58_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_availableproductcollection_product_values
    ADD CONSTRAINT content_library_availabl_availableproductcollecti_1ce63d58_uniq UNIQUE (availableproductcollection_id, productvalue_id);


--
-- Name: content_library_availableproductcollection content_library_availableproductcollection_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_availableproductcollection
    ADD CONSTRAINT content_library_availableproductcollection_pkey PRIMARY KEY (id);


--
-- Name: content_library_availableproductcollection_product_values content_library_availableproductcollection_product_values_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_availableproductcollection_product_values
    ADD CONSTRAINT content_library_availableproductcollection_product_values_pkey PRIMARY KEY (id);


--
-- Name: content_library_baseexperiment content_library_baseexperiment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_baseexperiment
    ADD CONSTRAINT content_library_baseexperiment_pkey PRIMARY KEY (id);


--
-- Name: content_library_basetemplate content_library_basetemplate_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_basetemplate
    ADD CONSTRAINT content_library_basetemplate_pkey PRIMARY KEY (id);


--
-- Name: content_library_basetreatment content_library_basetreatment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_basetreatment
    ADD CONSTRAINT content_library_basetreatment_pkey PRIMARY KEY (id);


--
-- Name: content_library_bodytemplatecontentblock content_library_bodytemp_body_template_id_content_013a096e_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_bodytemplatecontentblock
    ADD CONSTRAINT content_library_bodytemp_body_template_id_content_013a096e_uniq UNIQUE (body_template_id, content_block_id, "position");


--
-- Name: content_library_bodytemplate content_library_bodytemplate_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_bodytemplate
    ADD CONSTRAINT content_library_bodytemplate_pkey PRIMARY KEY (id);


--
-- Name: content_library_bodytemplatecontentblock content_library_bodytemplatecontentblock_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_bodytemplatecontentblock
    ADD CONSTRAINT content_library_bodytemplatecontentblock_pkey PRIMARY KEY (id);


--
-- Name: content_library_cheetahdigitalcreativecontentblockdocument content_library_cheetahd_content_block_id_creativ_d08dfcf4_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitalcreativecontentblockdocument
    ADD CONSTRAINT content_library_cheetahd_content_block_id_creativ_d08dfcf4_uniq UNIQUE (content_block_id, creative_id, ref_id);


--
-- Name: content_library_cheetahdigitalstaticcontentblockdocument content_library_cheetahd_content_block_id_ref_id_5c276e02_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitalstaticcontentblockdocument
    ADD CONSTRAINT content_library_cheetahd_content_block_id_ref_id_5c276e02_uniq UNIQUE (content_block_id, ref_id);


--
-- Name: content_library_cheetahdigitalcreativedocument content_library_cheetahd_creative_id_document_typ_233f7975_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitalcreativedocument
    ADD CONSTRAINT content_library_cheetahd_creative_id_document_typ_233f7975_uniq UNIQUE (creative_id, document_type, ref_id);


--
-- Name: content_library_cheetahdigitalcreativediscountofferdocument content_library_cheetahd_document_id_promotion_re_d3381873_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitalcreativediscountofferdocument
    ADD CONSTRAINT content_library_cheetahd_document_id_promotion_re_d3381873_uniq UNIQUE (document_id, promotion_redemption_id);


--
-- Name: content_library_cheetahdigitaleventmetadata content_library_cheetahd_event_id_campaign_id_fb13b6cd_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitaleventmetadata
    ADD CONSTRAINT content_library_cheetahd_event_id_campaign_id_fb13b6cd_uniq UNIQUE (event_id, campaign_id);


--
-- Name: content_library_cheetahdigital content_library_cheetahdigital_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigital
    ADD CONSTRAINT content_library_cheetahdigital_pkey PRIMARY KEY (emailserviceprovider_ptr_id);


--
-- Name: content_library_cheetahdigitalclientconfig content_library_cheetahdigitalclientconfig_esp_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitalclientconfig
    ADD CONSTRAINT content_library_cheetahdigitalclientconfig_esp_id_key UNIQUE (esp_id);


--
-- Name: content_library_cheetahdigitalclientconfig content_library_cheetahdigitalclientconfig_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitalclientconfig
    ADD CONSTRAINT content_library_cheetahdigitalclientconfig_pkey PRIMARY KEY (id);


--
-- Name: content_library_cheetahdigitalcreativecontentblockdocument content_library_cheetahdigitalcreativecontentblockdocument_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitalcreativecontentblockdocument
    ADD CONSTRAINT content_library_cheetahdigitalcreativecontentblockdocument_pkey PRIMARY KEY (id);


--
-- Name: content_library_cheetahdigitalcreativedocument content_library_cheetahdigitalcreativedocument_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitalcreativedocument
    ADD CONSTRAINT content_library_cheetahdigitalcreativedocument_pkey PRIMARY KEY (id);


--
-- Name: content_library_cheetahdigitalcreativediscountofferdocument content_library_cheetahdigitalcreativepromotiondocument_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitalcreativediscountofferdocument
    ADD CONSTRAINT content_library_cheetahdigitalcreativepromotiondocument_pkey PRIMARY KEY (id);


--
-- Name: content_library_cheetahdigitaleventmetadata content_library_cheetahdigitaleventmetadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitaleventmetadata
    ADD CONSTRAINT content_library_cheetahdigitaleventmetadata_pkey PRIMARY KEY (id);


--
-- Name: content_library_cheetahdigitallinkmetadata content_library_cheetahdigitallinkmetadata_link_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitallinkmetadata
    ADD CONSTRAINT content_library_cheetahdigitallinkmetadata_link_id_key UNIQUE (link_id);


--
-- Name: content_library_cheetahdigitallinkmetadata content_library_cheetahdigitallinkmetadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitallinkmetadata
    ADD CONSTRAINT content_library_cheetahdigitallinkmetadata_pkey PRIMARY KEY (id);


--
-- Name: content_library_cheetahdigitalstaticcontentblockdocument content_library_cheetahdigitalstaticcontentblockdocument_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitalstaticcontentblockdocument
    ADD CONSTRAINT content_library_cheetahdigitalstaticcontentblockdocument_pkey PRIMARY KEY (id);


--
-- Name: content_library_client content_library_client_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_client
    ADD CONSTRAINT content_library_client_name_key UNIQUE (name);


--
-- Name: content_library_client content_library_client_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_client
    ADD CONSTRAINT content_library_client_pkey PRIMARY KEY (id);


--
-- Name: content_library_clientconfiguration content_library_clientconfiguration__logo_square_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_clientconfiguration
    ADD CONSTRAINT content_library_clientconfiguration__logo_square_id_key UNIQUE (logo_square_id);


--
-- Name: content_library_clientconfiguration content_library_clientconfiguration_client_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_clientconfiguration
    ADD CONSTRAINT content_library_clientconfiguration_client_id_key UNIQUE (client_id);


--
-- Name: content_library_clientconfiguration content_library_clientconfiguration_logo_header_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_clientconfiguration
    ADD CONSTRAINT content_library_clientconfiguration_logo_header_id_key UNIQUE (logo_header_id);


--
-- Name: content_library_clientconfiguration content_library_clientconfiguration_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_clientconfiguration
    ADD CONSTRAINT content_library_clientconfiguration_pkey PRIMARY KEY (id);


--
-- Name: content_library_clientreuserule content_library_clientreuserule_client_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_clientreuserule
    ADD CONSTRAINT content_library_clientreuserule_client_id_key UNIQUE (client_id);


--
-- Name: content_library_clientreuserule content_library_clientreuserule_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_clientreuserule
    ADD CONSTRAINT content_library_clientreuserule_pkey PRIMARY KEY (id);


--
-- Name: content_library_clientuser content_library_clientus_user_id_organization_id_565adf52_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_clientuser
    ADD CONSTRAINT content_library_clientus_user_id_organization_id_565adf52_uniq UNIQUE (user_id, organization_id);


--
-- Name: content_library_clientuser content_library_clientuser_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_clientuser
    ADD CONSTRAINT content_library_clientuser_pkey PRIMARY KEY (id);


--
-- Name: content_library_clientuseradmin content_library_clientuseradmin_organization_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_clientuseradmin
    ADD CONSTRAINT content_library_clientuseradmin_organization_id_key UNIQUE (organization_id);


--
-- Name: content_library_clientuseradmin content_library_clientuseradmin_organization_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_clientuseradmin
    ADD CONSTRAINT content_library_clientuseradmin_organization_user_id_key UNIQUE (organization_user_id);


--
-- Name: content_library_clientuseradmin content_library_clientuseradmin_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_clientuseradmin
    ADD CONSTRAINT content_library_clientuseradmin_pkey PRIMARY KEY (id);


--
-- Name: content_library_contentblocktemplatetag content_library_contentb_content_block_id_templat_bc6c3bcf_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentblocktemplatetag
    ADD CONSTRAINT content_library_contentb_content_block_id_templat_bc6c3bcf_uniq UNIQUE (content_block_id, template_tag_id);


--
-- Name: content_library_contentblockcreativeversion content_library_contentb_creative_id_content_bloc_75a35081_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentblockcreativeversion
    ADD CONSTRAINT content_library_contentb_creative_id_content_bloc_75a35081_uniq UNIQUE (creative_id, content_block_id, "timestamp");


--
-- Name: content_library_contentblock content_library_contentblock_client_id_slug_ed79fdc6_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentblock
    ADD CONSTRAINT content_library_contentblock_client_id_slug_ed79fdc6_uniq UNIQUE (client_id, slug);


--
-- Name: content_library_contentblock content_library_contentblock_client_id_title_c8db9a65_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentblock
    ADD CONSTRAINT content_library_contentblock_client_id_title_c8db9a65_uniq UNIQUE (client_id, title);


--
-- Name: content_library_contentblock content_library_contentblock_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentblock
    ADD CONSTRAINT content_library_contentblock_pkey PRIMARY KEY (id);


--
-- Name: content_library_contentblockcreativeversion content_library_contentblockcreativeversion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentblockcreativeversion
    ADD CONSTRAINT content_library_contentblockcreativeversion_pkey PRIMARY KEY (id);


--
-- Name: content_library_contentblocktemplatetag content_library_contentblocktemplatetag_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentblocktemplatetag
    ADD CONSTRAINT content_library_contentblocktemplatetag_pkey PRIMARY KEY (id);


--
-- Name: content_library_contentpersonalizationmodeltreatment content_library_contentp_experiment_id_order_5de98166_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentpersonalizationmodeltreatment
    ADD CONSTRAINT content_library_contentp_experiment_id_order_5de98166_uniq UNIQUE (experiment_id, "order");


--
-- Name: content_library_contentpersonalizationmodelexperiment content_library_contentpersonalizationmodelexperiment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentpersonalizationmodelexperiment
    ADD CONSTRAINT content_library_contentpersonalizationmodelexperiment_pkey PRIMARY KEY (baseexperiment_ptr_id);


--
-- Name: content_library_contentpersonalizationmodeltreatment content_library_contentpersonalizationmodeltreatment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentpersonalizationmodeltreatment
    ADD CONSTRAINT content_library_contentpersonalizationmodeltreatment_pkey PRIMARY KEY (basetreatment_ptr_id);


--
-- Name: content_library_contentpersonalizationmodelvariant content_library_contentpersonalizationmodelvariant_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentpersonalizationmodelvariant
    ADD CONSTRAINT content_library_contentpersonalizationmodelvariant_pkey PRIMARY KEY (id);


--
-- Name: content_library_creative content_library_creative__promotion_card_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creative
    ADD CONSTRAINT content_library_creative__promotion_card_id_key UNIQUE (promotion_card_id);


--
-- Name: content_library_creative content_library_creative_client_id_slug_5ef3c775_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creative
    ADD CONSTRAINT content_library_creative_client_id_slug_5ef3c775_uniq UNIQUE (client_id, slug);


--
-- Name: content_library_creative_product_collections content_library_creative_creative_id_productcolle_9d77dd27_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creative_product_collections
    ADD CONSTRAINT content_library_creative_creative_id_productcolle_9d77dd27_uniq UNIQUE (creative_id, productcollection_id);


--
-- Name: content_library_creativepromotion content_library_creative_creative_id_promotion_id_fc926ca8_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creativepromotion
    ADD CONSTRAINT content_library_creative_creative_id_promotion_id_fc926ca8_uniq UNIQUE (creative_id, promotion_id);


--
-- Name: content_library_creative content_library_creative_disclaimer_image_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creative
    ADD CONSTRAINT content_library_creative_disclaimer_image_id_key UNIQUE (disclaimer_image_id);


--
-- Name: content_library_creative content_library_creative_disclaimer_link_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creative
    ADD CONSTRAINT content_library_creative_disclaimer_link_id_key UNIQUE (disclaimer_link_id);


--
-- Name: content_library_creative_prohibited_creatives content_library_creative_from_creative_id_to_crea_5cc52494_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creative_prohibited_creatives
    ADD CONSTRAINT content_library_creative_from_creative_id_to_crea_5cc52494_uniq UNIQUE (from_creative_id, to_creative_id);


--
-- Name: content_library_creative content_library_creative_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creative
    ADD CONSTRAINT content_library_creative_pkey PRIMARY KEY (id);


--
-- Name: content_library_creativeattribute content_library_creative_position_client_id_5adf474a_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creativeattribute
    ADD CONSTRAINT content_library_creative_position_client_id_5adf474a_uniq UNIQUE ("position", client_id);


--
-- Name: content_library_creative content_library_creative_preheader_link_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creative
    ADD CONSTRAINT content_library_creative_preheader_link_id_key UNIQUE (preheader_link_id);


--
-- Name: content_library_creative_product_collections content_library_creative_product_collections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creative_product_collections
    ADD CONSTRAINT content_library_creative_product_collections_pkey PRIMARY KEY (id);


--
-- Name: content_library_creative_prohibited_creatives content_library_creative_prohibited_creatives_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creative_prohibited_creatives
    ADD CONSTRAINT content_library_creative_prohibited_creatives_pkey PRIMARY KEY (id);


--
-- Name: content_library_creative_tags content_library_creative_tags_creative_id_tag_id_ccd3faed_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creative_tags
    ADD CONSTRAINT content_library_creative_tags_creative_id_tag_id_ccd3faed_uniq UNIQUE (creative_id, tag_id);


--
-- Name: content_library_creative_tags content_library_creative_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creative_tags
    ADD CONSTRAINT content_library_creative_tags_pkey PRIMARY KEY (id);


--
-- Name: content_library_creativeattributechoice content_library_creative_title_attribute_id_e36bc797_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creativeattributechoice
    ADD CONSTRAINT content_library_creative_title_attribute_id_e36bc797_uniq UNIQUE (title, attribute_id);


--
-- Name: content_library_creativeattribute content_library_creativeattribute_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creativeattribute
    ADD CONSTRAINT content_library_creativeattribute_pkey PRIMARY KEY (id);


--
-- Name: content_library_creativeattribute content_library_creativeattribute_slug_client_id_1041e3f2_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creativeattribute
    ADD CONSTRAINT content_library_creativeattribute_slug_client_id_1041e3f2_uniq UNIQUE (slug, client_id);


--
-- Name: content_library_creativeattribute content_library_creativeattribute_title_client_id_4b62d542_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creativeattribute
    ADD CONSTRAINT content_library_creativeattribute_title_client_id_4b62d542_uniq UNIQUE (title, client_id);


--
-- Name: content_library_creativeattributechoice content_library_creativeattributechoice_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creativeattributechoice
    ADD CONSTRAINT content_library_creativeattributechoice_pkey PRIMARY KEY (id);


--
-- Name: content_library_creativecontentblockdocument content_library_creativecontentblockdocument_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creativecontentblockdocument
    ADD CONSTRAINT content_library_creativecontentblockdocument_pkey PRIMARY KEY (id);


--
-- Name: content_library_creativepromotion content_library_creativepromotion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creativepromotion
    ADD CONSTRAINT content_library_creativepromotion_pkey PRIMARY KEY (id);


--
-- Name: content_library_creativereuserule content_library_creativereuserule_creative_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creativereuserule
    ADD CONSTRAINT content_library_creativereuserule_creative_id_key UNIQUE (creative_id);


--
-- Name: content_library_creativereuserule content_library_creativereuserule_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creativereuserule
    ADD CONSTRAINT content_library_creativereuserule_pkey PRIMARY KEY (id);


--
-- Name: content_library_creativestats content_library_creativestats_creative_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creativestats
    ADD CONSTRAINT content_library_creativestats_creative_id_key UNIQUE (creative_id);


--
-- Name: content_library_creativestats content_library_creativestats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creativestats
    ADD CONSTRAINT content_library_creativestats_pkey PRIMARY KEY (id);


--
-- Name: content_library_discountoffer content_library_discountoffer_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_discountoffer
    ADD CONSTRAINT content_library_discountoffer_pkey PRIMARY KEY (id);


--
-- Name: content_library_document content_library_document_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_document
    ADD CONSTRAINT content_library_document_pkey PRIMARY KEY (id);


--
-- Name: content_library_dynamicsectionvariant content_library_dynamics_section_id_event_audienc_7cfc3377_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_dynamicsectionvariant
    ADD CONSTRAINT content_library_dynamics_section_id_event_audienc_7cfc3377_uniq UNIQUE (section_id, event_audience_id, creatives_variant_id);


--
-- Name: content_library_dynamicsectionvariant content_library_dynamicsectionvariant_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_dynamicsectionvariant
    ADD CONSTRAINT content_library_dynamicsectionvariant_pkey PRIMARY KEY (id);


--
-- Name: content_library_eligiblecreativesvariant_treatments content_library_eligible_eligiblecreativesvariant_6112feea_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eligiblecreativesvariant_treatments
    ADD CONSTRAINT content_library_eligible_eligiblecreativesvariant_6112feea_uniq UNIQUE (eligiblecreativesvariant_id, eligiblecreativestreatment_id);


--
-- Name: content_library_eligiblecreativestreatment content_library_eligible_experiment_id_order_d95a69a0_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eligiblecreativestreatment
    ADD CONSTRAINT content_library_eligible_experiment_id_order_d95a69a0_uniq UNIQUE (experiment_id, "order");


--
-- Name: content_library_eligiblecreativesexperiment content_library_eligiblecreativesexperiment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eligiblecreativesexperiment
    ADD CONSTRAINT content_library_eligiblecreativesexperiment_pkey PRIMARY KEY (baseexperiment_ptr_id);


--
-- Name: content_library_eligiblecreativestreatment content_library_eligiblecreativestreatment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eligiblecreativestreatment
    ADD CONSTRAINT content_library_eligiblecreativestreatment_pkey PRIMARY KEY (basetreatment_ptr_id);


--
-- Name: content_library_eligiblecreativesvariant content_library_eligiblecreativesvariant_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eligiblecreativesvariant
    ADD CONSTRAINT content_library_eligiblecreativesvariant_pkey PRIMARY KEY (id);


--
-- Name: content_library_eligiblecreativesvariant_treatments content_library_eligiblecreativesvariant_treatments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eligiblecreativesvariant_treatments
    ADD CONSTRAINT content_library_eligiblecreativesvariant_treatments_pkey PRIMARY KEY (id);


--
-- Name: content_library_emailserviceprovider content_library_emailserviceprovider_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_emailserviceprovider
    ADD CONSTRAINT content_library_emailserviceprovider_pkey PRIMARY KEY (id);


--
-- Name: content_library_event content_library_event_client_id_slug_7aeda8a6_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_event
    ADD CONSTRAINT content_library_event_client_id_slug_7aeda8a6_uniq UNIQUE (client_id, slug);


--
-- Name: content_library_event content_library_event_client_id_title_1eee98c9_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_event
    ADD CONSTRAINT content_library_event_client_id_title_1eee98c9_uniq UNIQUE (client_id, title);


--
-- Name: content_library_event content_library_event_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_event
    ADD CONSTRAINT content_library_event_pkey PRIMARY KEY (id);


--
-- Name: content_library_event_tags content_library_event_tags_event_id_tag_id_8a5f42fd_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_event_tags
    ADD CONSTRAINT content_library_event_tags_event_id_tag_id_8a5f42fd_uniq UNIQUE (event_id, tag_id);


--
-- Name: content_library_event_tags content_library_event_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_event_tags
    ADD CONSTRAINT content_library_event_tags_pkey PRIMARY KEY (id);


--
-- Name: content_library_eventacousticcampaignconfig content_library_eventacousticcampaignconfig_event_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventacousticcampaignconfig
    ADD CONSTRAINT content_library_eventacousticcampaignconfig_event_id_key UNIQUE (event_id);


--
-- Name: content_library_eventacousticcampaignconfig content_library_eventacousticcampaignconfig_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventacousticcampaignconfig
    ADD CONSTRAINT content_library_eventacousticcampaignconfig_pkey PRIMARY KEY (id);


--
-- Name: content_library_eventattributechoice content_library_eventatt_title_attribute_id_424fb06b_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventattributechoice
    ADD CONSTRAINT content_library_eventatt_title_attribute_id_424fb06b_uniq UNIQUE (title, attribute_id);


--
-- Name: content_library_eventattribute content_library_eventattribute_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventattribute
    ADD CONSTRAINT content_library_eventattribute_pkey PRIMARY KEY (id);


--
-- Name: content_library_eventattribute content_library_eventattribute_position_client_id_6b6f7b48_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventattribute
    ADD CONSTRAINT content_library_eventattribute_position_client_id_6b6f7b48_uniq UNIQUE ("position", client_id);


--
-- Name: content_library_eventattribute content_library_eventattribute_slug_client_id_4fc46d19_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventattribute
    ADD CONSTRAINT content_library_eventattribute_slug_client_id_4fc46d19_uniq UNIQUE (slug, client_id);


--
-- Name: content_library_eventattribute content_library_eventattribute_title_client_id_04337e22_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventattribute
    ADD CONSTRAINT content_library_eventattribute_title_client_id_04337e22_uniq UNIQUE (title, client_id);


--
-- Name: content_library_eventattributecheetahdigitaloptionid content_library_eventattributecheetahdig_event_attribute_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventattributecheetahdigitaloptionid
    ADD CONSTRAINT content_library_eventattributecheetahdig_event_attribute_id_key UNIQUE (event_attribute_id);


--
-- Name: content_library_eventattributecheetahdigitaloptionid content_library_eventattributecheetahdigitaloptionid_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventattributecheetahdigitaloptionid
    ADD CONSTRAINT content_library_eventattributecheetahdigitaloptionid_pkey PRIMARY KEY (id);


--
-- Name: content_library_eventattributechoicecheetahdigitalselectionid content_library_eventattributecho_event_attribute_choice_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventattributechoicecheetahdigitalselectionid
    ADD CONSTRAINT content_library_eventattributecho_event_attribute_choice_id_key UNIQUE (event_attribute_choice_id);


--
-- Name: content_library_eventattributechoice content_library_eventattributechoice_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventattributechoice
    ADD CONSTRAINT content_library_eventattributechoice_pkey PRIMARY KEY (id);


--
-- Name: content_library_eventattributechoicecheetahdigitalselectionid content_library_eventattributechoicecheetahdigitalselectio_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventattributechoicecheetahdigitalselectionid
    ADD CONSTRAINT content_library_eventattributechoicecheetahdigitalselectio_pkey PRIMARY KEY (id);


--
-- Name: content_library_eventattributeoracleresponsyscampaignvariable content_library_eventattributeoracleresp_event_attribute_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventattributeoracleresponsyscampaignvariable
    ADD CONSTRAINT content_library_eventattributeoracleresp_event_attribute_id_key UNIQUE (event_attribute_id);


--
-- Name: content_library_eventattributeoracleresponsyscampaignvariable content_library_eventattributeoracleresponsyscampaignvaria_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventattributeoracleresponsyscampaignvariable
    ADD CONSTRAINT content_library_eventattributeoracleresponsyscampaignvaria_pkey PRIMARY KEY (id);


--
-- Name: content_library_eventaudience content_library_eventaud_event_id_audience_filter_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventaudience
    ADD CONSTRAINT content_library_eventaud_event_id_audience_filter_uniq UNIQUE (event_id, audience_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventaudience content_library_eventaudiencefilter_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventaudience
    ADD CONSTRAINT content_library_eventaudiencefilter_pkey PRIMARY KEY (id);


--
-- Name: content_library_eventcontentblockcreativestats content_library_eventcon_event_id_content_block_i_93dd66bd_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventcontentblockcreativestats
    ADD CONSTRAINT content_library_eventcon_event_id_content_block_i_93dd66bd_uniq UNIQUE (event_id, content_block_id);


--
-- Name: content_library_eventcontentblockcreativestats content_library_eventcontentblockcreativestats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventcontentblockcreativestats
    ADD CONSTRAINT content_library_eventcontentblockcreativestats_pkey PRIMARY KEY (id);


--
-- Name: content_library_eventcontentblockstats content_library_eventcontentblockstats_event_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventcontentblockstats
    ADD CONSTRAINT content_library_eventcontentblockstats_event_id_key UNIQUE (event_id);


--
-- Name: content_library_eventcontentblockstats content_library_eventcontentblockstats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventcontentblockstats
    ADD CONSTRAINT content_library_eventcontentblockstats_pkey PRIMARY KEY (id);


--
-- Name: content_library_eventcreativestats content_library_eventcreativestats_event_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventcreativestats
    ADD CONSTRAINT content_library_eventcreativestats_event_id_key UNIQUE (event_id);


--
-- Name: content_library_eventcreativestats content_library_eventcreativestats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventcreativestats
    ADD CONSTRAINT content_library_eventcreativestats_pkey PRIMARY KEY (id);


--
-- Name: content_library_eventexperimentstats content_library_eventexperimentstats_event_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventexperimentstats
    ADD CONSTRAINT content_library_eventexperimentstats_event_id_key UNIQUE (event_id);


--
-- Name: content_library_eventexperimentstats content_library_eventexperimentstats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventexperimentstats
    ADD CONSTRAINT content_library_eventexperimentstats_pkey PRIMARY KEY (id);


--
-- Name: content_library_eventoracleresponsysconfig_additional_data_13a0 content_library_eventora_eventoracleresponsysconf_52407467_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventoracleresponsysconfig_additional_data_13a0
    ADD CONSTRAINT content_library_eventora_eventoracleresponsysconf_52407467_uniq UNIQUE (eventoracleresponsysconfig_id, oracleresponsysadditionaldatasource_id);


--
-- Name: content_library_eventoracleresponsysconfig_suppressions content_library_eventora_eventoracleresponsysconf_e239ce7e_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventoracleresponsysconfig_suppressions
    ADD CONSTRAINT content_library_eventora_eventoracleresponsysconf_e239ce7e_uniq UNIQUE (eventoracleresponsysconfig_id, oracleresponsyssuppression_id);


--
-- Name: content_library_eventoracleresponsysconfig_additional_data_13a0 content_library_eventoracleresponsysconfig_additional_data_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventoracleresponsysconfig_additional_data_13a0
    ADD CONSTRAINT content_library_eventoracleresponsysconfig_additional_data_pkey PRIMARY KEY (id);


--
-- Name: content_library_eventoracleresponsysconfig content_library_eventoracleresponsysconfig_event_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventoracleresponsysconfig
    ADD CONSTRAINT content_library_eventoracleresponsysconfig_event_id_key UNIQUE (event_id);


--
-- Name: content_library_eventoracleresponsysconfig content_library_eventoracleresponsysconfig_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventoracleresponsysconfig
    ADD CONSTRAINT content_library_eventoracleresponsysconfig_pkey PRIMARY KEY (id);


--
-- Name: content_library_eventoracleresponsysconfig_suppressions content_library_eventoracleresponsysconfig_suppressions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventoracleresponsysconfig_suppressions
    ADD CONSTRAINT content_library_eventoracleresponsysconfig_suppressions_pkey PRIMARY KEY (id);


--
-- Name: content_library_eventrun content_library_eventrun_event_id_run_id_3efdb503_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventrun
    ADD CONSTRAINT content_library_eventrun_event_id_run_id_3efdb503_uniq UNIQUE (event_id, run_id);


--
-- Name: content_library_eventrun content_library_eventrun_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventrun
    ADD CONSTRAINT content_library_eventrun_pkey PRIMARY KEY (id);


--
-- Name: content_library_eventsalesforcemarketingcloudconfig_suppresa376 content_library_eventsal_eventsalesforcemarketing_843743f2_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventsalesforcemarketingcloudconfig_suppresa376
    ADD CONSTRAINT content_library_eventsal_eventsalesforcemarketing_843743f2_uniq UNIQUE (eventsalesforcemarketingcloudconfig_id, salesforcemarketingcloudsuppressiondataextension_id);


--
-- Name: content_library_eventsalesforcemarketingcloudconfig content_library_eventsalesforcemarketingcloudconfi_event_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventsalesforcemarketingcloudconfig
    ADD CONSTRAINT content_library_eventsalesforcemarketingcloudconfi_event_id_key UNIQUE (event_id);


--
-- Name: content_library_eventsalesforcemarketingcloudconfig content_library_eventsalesforcemarketingcloudconfig_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventsalesforcemarketingcloudconfig
    ADD CONSTRAINT content_library_eventsalesforcemarketingcloudconfig_pkey PRIMARY KEY (id);


--
-- Name: content_library_eventsalesforcemarketingcloudconfig_suppresa376 content_library_eventsalesforcemarketingcloudconfig_suppre_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventsalesforcemarketingcloudconfig_suppresa376
    ADD CONSTRAINT content_library_eventsalesforcemarketingcloudconfig_suppre_pkey PRIMARY KEY (id);


--
-- Name: content_library_eventstatus content_library_eventsta_event_id_status_timestam_6e0dd59d_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventstatus
    ADD CONSTRAINT content_library_eventsta_event_id_status_timestam_6e0dd59d_uniq UNIQUE (event_id, status, "timestamp");


--
-- Name: content_library_eventstats content_library_eventstats_event_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventstats
    ADD CONSTRAINT content_library_eventstats_event_id_key UNIQUE (event_id);


--
-- Name: content_library_eventstats content_library_eventstats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventstats
    ADD CONSTRAINT content_library_eventstats_pkey PRIMARY KEY (id);


--
-- Name: content_library_eventstatus content_library_eventstatus_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventstatus
    ADD CONSTRAINT content_library_eventstatus_pkey PRIMARY KEY (id);


--
-- Name: content_library_eventtasklog content_library_eventtas_event_id_task_id_task_na_296393aa_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventtasklog
    ADD CONSTRAINT content_library_eventtas_event_id_task_id_task_na_296393aa_uniq UNIQUE (event_id, task_id, task_name);


--
-- Name: content_library_eventtasklog content_library_eventtasklog_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventtasklog
    ADD CONSTRAINT content_library_eventtasklog_pkey PRIMARY KEY (id);


--
-- Name: content_library_eventtrackingpixel content_library_eventtrackingpixel_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventtrackingpixel
    ADD CONSTRAINT content_library_eventtrackingpixel_pkey PRIMARY KEY (id);


--
-- Name: content_library_footertemplatecontentblock content_library_footerte_footer_template_id_conte_a0221bf7_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_footertemplatecontentblock
    ADD CONSTRAINT content_library_footerte_footer_template_id_conte_a0221bf7_uniq UNIQUE (footer_template_id, content_block_id, "position");


--
-- Name: content_library_footertemplate content_library_footertemplate_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_footertemplate
    ADD CONSTRAINT content_library_footertemplate_pkey PRIMARY KEY (id);


--
-- Name: content_library_footertemplatecontentblock content_library_footertemplatecontentblock_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_footertemplatecontentblock
    ADD CONSTRAINT content_library_footertemplatecontentblock_pkey PRIMARY KEY (id);


--
-- Name: content_library_freegift content_library_freegift_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_freegift
    ADD CONSTRAINT content_library_freegift_pkey PRIMARY KEY (id);


--
-- Name: content_library_headertemplatecontentblock content_library_headerte_header_template_id_conte_1b1eb0bb_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_headertemplatecontentblock
    ADD CONSTRAINT content_library_headerte_header_template_id_conte_1b1eb0bb_uniq UNIQUE (header_template_id, content_block_id, "position");


--
-- Name: content_library_headertemplate content_library_headertemplate_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_headertemplate
    ADD CONSTRAINT content_library_headertemplate_pkey PRIMARY KEY (id);


--
-- Name: content_library_headertemplatecontentblock content_library_headertemplatecontentblock_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_headertemplatecontentblock
    ADD CONSTRAINT content_library_headertemplatecontentblock_pkey PRIMARY KEY (id);


--
-- Name: content_library_htmlbundlelink content_library_htmlbund_html_bundle_id_link_id_d15d01e1_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_htmlbundlelink
    ADD CONSTRAINT content_library_htmlbund_html_bundle_id_link_id_d15d01e1_uniq UNIQUE (html_bundle_id, link_id);


--
-- Name: content_library_htmlbundle content_library_htmlbundle_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_htmlbundle
    ADD CONSTRAINT content_library_htmlbundle_pkey PRIMARY KEY (id);


--
-- Name: content_library_htmlbundleimage content_library_htmlbundleimage_image_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_htmlbundleimage
    ADD CONSTRAINT content_library_htmlbundleimage_image_id_key UNIQUE (image_id);


--
-- Name: content_library_htmlbundleimage content_library_htmlbundleimage_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_htmlbundleimage
    ADD CONSTRAINT content_library_htmlbundleimage_pkey PRIMARY KEY (id);


--
-- Name: content_library_htmlbundlelink content_library_htmlbundlelink_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_htmlbundlelink
    ADD CONSTRAINT content_library_htmlbundlelink_pkey PRIMARY KEY (id);


--
-- Name: content_library_image content_library_image_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_image
    ADD CONSTRAINT content_library_image_pkey PRIMARY KEY (id);


--
-- Name: content_library_imagelayout content_library_imagelayout_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_imagelayout
    ADD CONSTRAINT content_library_imagelayout_pkey PRIMARY KEY (id);


--
-- Name: content_library_imageslice content_library_imageslice_image_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_imageslice
    ADD CONSTRAINT content_library_imageslice_image_id_key UNIQUE (image_id);


--
-- Name: content_library_imageslice content_library_imageslice_link_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_imageslice
    ADD CONSTRAINT content_library_imageslice_link_id_key UNIQUE (link_id);


--
-- Name: content_library_imageslice content_library_imageslice_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_imageslice
    ADD CONSTRAINT content_library_imageslice_pkey PRIMARY KEY (id);


--
-- Name: content_library_inboxpreview content_library_inboxpre_event_audience_id_creati_bed23e96_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_inboxpreview
    ADD CONSTRAINT content_library_inboxpre_event_audience_id_creati_bed23e96_uniq UNIQUE (event_audience_id, creatives_variant_id);


--
-- Name: content_library_inboxpreview content_library_inboxpreview_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_inboxpreview
    ADD CONSTRAINT content_library_inboxpreview_pkey PRIMARY KEY (id);


--
-- Name: content_library_invitation content_library_invitation_client_id_email_68f4325d_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_invitation
    ADD CONSTRAINT content_library_invitation_client_id_email_68f4325d_uniq UNIQUE (client_id, email);


--
-- Name: content_library_invitation content_library_invitation_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_invitation
    ADD CONSTRAINT content_library_invitation_key_key UNIQUE (key);


--
-- Name: content_library_invitation content_library_invitation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_invitation
    ADD CONSTRAINT content_library_invitation_pkey PRIMARY KEY (id);


--
-- Name: content_library_layout content_library_layout_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_layout
    ADD CONSTRAINT content_library_layout_pkey PRIMARY KEY (id);


--
-- Name: content_library_linkcategory content_library_linkcategory_client_id_title_a5738011_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_linkcategory
    ADD CONSTRAINT content_library_linkcategory_client_id_title_a5738011_uniq UNIQUE (client_id, title);


--
-- Name: content_library_linkcategory content_library_linkcategory_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_linkcategory
    ADD CONSTRAINT content_library_linkcategory_pkey PRIMARY KEY (id);


--
-- Name: content_library_linkgroup content_library_linkgroup_client_id_name_f4535c5a_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_linkgroup
    ADD CONSTRAINT content_library_linkgroup_client_id_name_f4535c5a_uniq UNIQUE (client_id, name);


--
-- Name: content_library_linkgroup content_library_linkgroup_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_linkgroup
    ADD CONSTRAINT content_library_linkgroup_pkey PRIMARY KEY (id);


--
-- Name: content_library_movableinkcreative content_library_movableinkcreative_creative_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_movableinkcreative
    ADD CONSTRAINT content_library_movableinkcreative_creative_id_key UNIQUE (creative_id);


--
-- Name: content_library_movableinkcreative content_library_movableinkcreative_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_movableinkcreative
    ADD CONSTRAINT content_library_movableinkcreative_pkey PRIMARY KEY (id);


--
-- Name: content_library_movableinkintegration content_library_movableinkintegration_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_movableinkintegration
    ADD CONSTRAINT content_library_movableinkintegration_pkey PRIMARY KEY (id);


--
-- Name: content_library_movableinkintegration content_library_movableinkintegration_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_movableinkintegration
    ADD CONSTRAINT content_library_movableinkintegration_user_id_key UNIQUE (user_id);


--
-- Name: content_library_neweligiblecreative content_library_neweligi_section_variant_id_creat_593c465c_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_neweligiblecreative
    ADD CONSTRAINT content_library_neweligi_section_variant_id_creat_593c465c_uniq UNIQUE (section_variant_id, creative_id);


--
-- Name: content_library_neweligiblecreative content_library_neweligiblecreative_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_neweligiblecreative
    ADD CONSTRAINT content_library_neweligiblecreative_pkey PRIMARY KEY (id);


--
-- Name: content_library_link content_library_newlink_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_link
    ADD CONSTRAINT content_library_newlink_pkey PRIMARY KEY (id);


--
-- Name: content_library_link content_library_newlink_short_uuid_6870e745_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_link
    ADD CONSTRAINT content_library_newlink_short_uuid_6870e745_uniq UNIQUE (short_uuid);


--
-- Name: content_library_neworacleresponsysclientconfig content_library_neworacleresponsysclientconfig_client_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_neworacleresponsysclientconfig
    ADD CONSTRAINT content_library_neworacleresponsysclientconfig_client_id_key UNIQUE (client_id);


--
-- Name: content_library_neworacleresponsysclientconfig content_library_neworacleresponsysclientconfig_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_neworacleresponsysclientconfig
    ADD CONSTRAINT content_library_neworacleresponsysclientconfig_pkey PRIMARY KEY (id);


--
-- Name: content_library_senddatetime content_library_newsendd_send_time_personalizatio_8de8755a_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_senddatetime
    ADD CONSTRAINT content_library_newsendd_send_time_personalizatio_8de8755a_uniq UNIQUE (send_time_personalization_variant_id, send_datetime_range);


--
-- Name: content_library_senddatetime content_library_newsenddatetime_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_senddatetime
    ADD CONSTRAINT content_library_newsenddatetime_pkey PRIMARY KEY (id);


--
-- Name: content_library_offer content_library_offer_client_id_offer_type_off_acf37b80_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_offer
    ADD CONSTRAINT content_library_offer_client_id_offer_type_off_acf37b80_uniq UNIQUE (client_id, offer_type, offer_detail_id);


--
-- Name: content_library_offer content_library_offer_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_offer
    ADD CONSTRAINT content_library_offer_pkey PRIMARY KEY (id);


--
-- Name: content_library_oracleresponsyscampaignvariablechoice content_library_oraclere_campaign_variable_id_tit_fc630e41_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyscampaignvariablechoice
    ADD CONSTRAINT content_library_oraclere_campaign_variable_id_tit_fc630e41_uniq UNIQUE (campaign_variable_id, title);


--
-- Name: content_library_oracleresponsyscreativecontentblockdocument content_library_oraclere_content_block_id_creativ_8735f61e_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyscreativecontentblockdocument
    ADD CONSTRAINT content_library_oraclere_content_block_id_creativ_8735f61e_uniq UNIQUE (content_block_id, creative_id, document_name);


--
-- Name: content_library_oracleresponsysstaticcontentblockdocument content_library_oraclere_content_block_id_documen_ff05e139_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsysstaticcontentblockdocument
    ADD CONSTRAINT content_library_oraclere_content_block_id_documen_ff05e139_uniq UNIQUE (content_block_id, document_name);


--
-- Name: content_library_oracleresponsyscreativediscountofferdocument content_library_oraclere_document_id_promotion_re_44f61ff4_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyscreativediscountofferdocument
    ADD CONSTRAINT content_library_oraclere_document_id_promotion_re_44f61ff4_uniq UNIQUE (document_id, promotion_redemption_id);


--
-- Name: content_library_oracleresponsyscreativedocument content_library_oraclere_document_type_creative_i_c8d27a2f_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyscreativedocument
    ADD CONSTRAINT content_library_oraclere_document_type_creative_i_c8d27a2f_uniq UNIQUE (document_type, creative_id, document_name);


--
-- Name: content_library_oracleresponsyslaunch content_library_oraclere_event_id_campaign_id_lau_ab6ad324_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyslaunch
    ADD CONSTRAINT content_library_oraclere_event_id_campaign_id_lau_ab6ad324_uniq UNIQUE (event_id, campaign_id, launch_id);


--
-- Name: content_library_oracleresponsysclientconfig content_library_oraclerespons_additional_pets_event_attribu_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsysclientconfig
    ADD CONSTRAINT content_library_oraclerespons_additional_pets_event_attribu_key UNIQUE (additional_pets_event_attribute_id);


--
-- Name: content_library_oracleresponsysclientconfig content_library_oraclerespons_external_campaign_code_event__key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsysclientconfig
    ADD CONSTRAINT content_library_oraclerespons_external_campaign_code_event__key UNIQUE (external_campaign_code_event_attribute_id);


--
-- Name: content_library_oracleresponsys content_library_oracleresponsys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsys
    ADD CONSTRAINT content_library_oracleresponsys_pkey PRIMARY KEY (emailserviceprovider_ptr_id);


--
-- Name: content_library_oracleresponsysadditionaldatasource content_library_oracleresponsysadditionaldatasource_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsysadditionaldatasource
    ADD CONSTRAINT content_library_oracleresponsysadditionaldatasource_pkey PRIMARY KEY (id);


--
-- Name: content_library_oracleresponsyscampaignvariable content_library_oracleresponsyscampaignvariable_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyscampaignvariable
    ADD CONSTRAINT content_library_oracleresponsyscampaignvariable_pkey PRIMARY KEY (id);


--
-- Name: content_library_oracleresponsyscampaignvariablechoice content_library_oracleresponsyscampaignvariablechoice_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyscampaignvariablechoice
    ADD CONSTRAINT content_library_oracleresponsyscampaignvariablechoice_pkey PRIMARY KEY (id);


--
-- Name: content_library_oracleresponsysclientconfig content_library_oracleresponsysclientconfig_esp_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsysclientconfig
    ADD CONSTRAINT content_library_oracleresponsysclientconfig_esp_id_key UNIQUE (esp_id);


--
-- Name: content_library_oracleresponsysclientconfig content_library_oracleresponsysclientconfig_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsysclientconfig
    ADD CONSTRAINT content_library_oracleresponsysclientconfig_pkey PRIMARY KEY (id);


--
-- Name: content_library_oracleresponsyscreativecontentblockdocument content_library_oracleresponsyscreativecontentblockdocumen_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyscreativecontentblockdocument
    ADD CONSTRAINT content_library_oracleresponsyscreativecontentblockdocumen_pkey PRIMARY KEY (id);


--
-- Name: content_library_oracleresponsyscreativedocument content_library_oracleresponsyscreativedocument_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyscreativedocument
    ADD CONSTRAINT content_library_oracleresponsyscreativedocument_pkey PRIMARY KEY (id);


--
-- Name: content_library_oracleresponsyscreativediscountofferdocument content_library_oracleresponsyscreativepromotiondocument_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyscreativediscountofferdocument
    ADD CONSTRAINT content_library_oracleresponsyscreativepromotiondocument_pkey PRIMARY KEY (id);


--
-- Name: content_library_oracleresponsyslaunch content_library_oracleresponsyseventmetadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyslaunch
    ADD CONSTRAINT content_library_oracleresponsyseventmetadata_pkey PRIMARY KEY (id);


--
-- Name: content_library_oracleresponsyslinkmetadata content_library_oracleresponsyslinkmetadata_link_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyslinkmetadata
    ADD CONSTRAINT content_library_oracleresponsyslinkmetadata_link_id_key UNIQUE (link_id);


--
-- Name: content_library_oracleresponsyslinkmetadata content_library_oracleresponsyslinkmetadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyslinkmetadata
    ADD CONSTRAINT content_library_oracleresponsyslinkmetadata_pkey PRIMARY KEY (id);


--
-- Name: content_library_oracleresponsyslist content_library_oracleresponsyslist_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyslist
    ADD CONSTRAINT content_library_oracleresponsyslist_pkey PRIMARY KEY (id);


--
-- Name: content_library_oracleresponsysmarketingprogram content_library_oracleresponsysmarketingprogram_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsysmarketingprogram
    ADD CONSTRAINT content_library_oracleresponsysmarketingprogram_pkey PRIMARY KEY (id);


--
-- Name: content_library_oracleresponsysmarketingstrategy content_library_oracleresponsysmarketingstrategy_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsysmarketingstrategy
    ADD CONSTRAINT content_library_oracleresponsysmarketingstrategy_pkey PRIMARY KEY (id);


--
-- Name: content_library_oracleresponsyssenderprofile content_library_oracleresponsyssenderprofile_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyssenderprofile
    ADD CONSTRAINT content_library_oracleresponsyssenderprofile_pkey PRIMARY KEY (id);


--
-- Name: content_library_oracleresponsysstaticcontentblockdocument content_library_oracleresponsysstaticcontentblockdocument_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsysstaticcontentblockdocument
    ADD CONSTRAINT content_library_oracleresponsysstaticcontentblockdocument_pkey PRIMARY KEY (id);


--
-- Name: content_library_oracleresponsyssuppression content_library_oracleresponsyssuppression_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyssuppression
    ADD CONSTRAINT content_library_oracleresponsyssuppression_pkey PRIMARY KEY (id);


--
-- Name: content_library_persadocampaign content_library_persadoc_client_id_campaign_id_bd9b0489_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_persadocampaign
    ADD CONSTRAINT content_library_persadoc_client_id_campaign_id_bd9b0489_uniq UNIQUE (client_id, campaign_id);


--
-- Name: content_library_persadocampaign content_library_persadocampaign_client_id_title_a4d1862b_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_persadocampaign
    ADD CONSTRAINT content_library_persadocampaign_client_id_title_a4d1862b_uniq UNIQUE (client_id, title);


--
-- Name: content_library_persadocampaign content_library_persadocampaign_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_persadocampaign
    ADD CONSTRAINT content_library_persadocampaign_pkey PRIMARY KEY (id);


--
-- Name: content_library_predefinedlayoutstructure content_library_predefinedlayoutstructure_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_predefinedlayoutstructure
    ADD CONSTRAINT content_library_predefinedlayoutstructure_pkey PRIMARY KEY (id);


--
-- Name: content_library_predefinedlayoutstructure content_library_predefinedlayoutstructure_title_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_predefinedlayoutstructure
    ADD CONSTRAINT content_library_predefinedlayoutstructure_title_key UNIQUE (title);


--
-- Name: content_library_productcollection_product_values content_library_productc_productcollection_id_pro_1caca051_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_productcollection_product_values
    ADD CONSTRAINT content_library_productc_productcollection_id_pro_1caca051_uniq UNIQUE (productcollection_id, productvalue_id);


--
-- Name: content_library_productcollection content_library_productcollection_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_productcollection
    ADD CONSTRAINT content_library_productcollection_pkey PRIMARY KEY (id);


--
-- Name: content_library_productcollection_product_values content_library_productcollection_product_values_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_productcollection_product_values
    ADD CONSTRAINT content_library_productcollection_product_values_pkey PRIMARY KEY (id);


--
-- Name: content_library_productfield content_library_productf_client_id_id_field_name_726aec2d_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_productfield
    ADD CONSTRAINT content_library_productf_client_id_id_field_name_726aec2d_uniq UNIQUE (client_id, id_field_name);


--
-- Name: content_library_productfield content_library_productfield_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_productfield
    ADD CONSTRAINT content_library_productfield_pkey PRIMARY KEY (id);


--
-- Name: content_library_productvalue content_library_productv_product_field_id_externa_b739f07e_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_productvalue
    ADD CONSTRAINT content_library_productv_product_field_id_externa_b739f07e_uniq UNIQUE (product_field_id, external_id, description);


--
-- Name: content_library_productvalue content_library_productvalue_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_productvalue
    ADD CONSTRAINT content_library_productvalue_pkey PRIMARY KEY (id);


--
-- Name: content_library_prohibitedcreativeproductcollection content_library_prohibit_creative_id_productcolle_b1057b85_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_prohibitedcreativeproductcollection
    ADD CONSTRAINT content_library_prohibit_creative_id_productcolle_b1057b85_uniq UNIQUE (creative_id, productcollection_id);


--
-- Name: content_library_prohibitedcreativetag content_library_prohibit_creative_id_tag_id_facfedfa_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_prohibitedcreativetag
    ADD CONSTRAINT content_library_prohibit_creative_id_tag_id_facfedfa_uniq UNIQUE (creative_id, tag_id);


--
-- Name: content_library_prohibitedcreativeproductcollection content_library_prohibitedcreativeproductcollection_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_prohibitedcreativeproductcollection
    ADD CONSTRAINT content_library_prohibitedcreativeproductcollection_pkey PRIMARY KEY (id);


--
-- Name: content_library_prohibitedcreativetag content_library_prohibitedcreativetag_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_prohibitedcreativetag
    ADD CONSTRAINT content_library_prohibitedcreativetag_pkey PRIMARY KEY (id);


--
-- Name: content_library_promotionoffer content_library_promotio_promotion_id_offer_id_d6f9ca3f_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_promotionoffer
    ADD CONSTRAINT content_library_promotio_promotion_id_offer_id_d6f9ca3f_uniq UNIQUE (promotion_id, offer_id);


--
-- Name: content_library_promotion content_library_promotion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_promotion
    ADD CONSTRAINT content_library_promotion_pkey PRIMARY KEY (id);


--
-- Name: content_library_promotionoffer content_library_promotionoffer_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_promotionoffer
    ADD CONSTRAINT content_library_promotionoffer_pkey PRIMARY KEY (id);


--
-- Name: content_library_promotionredemption content_library_promotionredemption_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_promotionredemption
    ADD CONSTRAINT content_library_promotionredemption_pkey PRIMARY KEY (id);


--
-- Name: content_library_proxycontroltreatment content_library_proxycon_experiment_id_order_046cbdeb_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_proxycontroltreatment
    ADD CONSTRAINT content_library_proxycon_experiment_id_order_046cbdeb_uniq UNIQUE (experiment_id, "order");


--
-- Name: content_library_proxycontrolexperiment content_library_proxycontrolexperiment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_proxycontrolexperiment
    ADD CONSTRAINT content_library_proxycontrolexperiment_pkey PRIMARY KEY (baseexperiment_ptr_id);


--
-- Name: content_library_proxycontroltreatment content_library_proxycontroltreatment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_proxycontroltreatment
    ADD CONSTRAINT content_library_proxycontroltreatment_pkey PRIMARY KEY (basetreatment_ptr_id);


--
-- Name: content_library_proxycontrolvariant content_library_proxycontrolvariant_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_proxycontrolvariant
    ADD CONSTRAINT content_library_proxycontrolvariant_pkey PRIMARY KEY (id);


--
-- Name: content_library_quantitydiscount content_library_quantitydiscount_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_quantitydiscount
    ADD CONSTRAINT content_library_quantitydiscount_pkey PRIMARY KEY (id);


--
-- Name: content_library_querystringparameter content_library_querystr_client_id_key_e141e81a_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_querystringparameter
    ADD CONSTRAINT content_library_querystr_client_id_key_e141e81a_uniq UNIQUE (client_id, key);


--
-- Name: content_library_querystringparameter content_library_querystringparameter_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_querystringparameter
    ADD CONSTRAINT content_library_querystringparameter_pkey PRIMARY KEY (id);


--
-- Name: content_library_recommendationrun content_library_recommen_client_id_run_id_74f2861f_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_recommendationrun
    ADD CONSTRAINT content_library_recommen_client_id_run_id_74f2861f_uniq UNIQUE (client_id, run_id);


--
-- Name: content_library_contentpersonalizationmodel content_library_recommen_major_minor_c0087ce7_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentpersonalizationmodel
    ADD CONSTRAINT content_library_recommen_major_minor_c0087ce7_uniq UNIQUE (major, minor);


--
-- Name: content_library_recommendationrunlog content_library_recommen_recommendation_run_id_ev_193321f1_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_recommendationrunlog
    ADD CONSTRAINT content_library_recommen_recommendation_run_id_ev_193321f1_uniq UNIQUE (recommendation_run_id, event_id, status);


--
-- Name: content_library_recommendationrun_events content_library_recommen_recommendationrun_id_eve_90e0098a_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_recommendationrun_events
    ADD CONSTRAINT content_library_recommen_recommendationrun_id_eve_90e0098a_uniq UNIQUE (recommendationrun_id, event_id);


--
-- Name: content_library_recommendationrun_events content_library_recommendationrun_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_recommendationrun_events
    ADD CONSTRAINT content_library_recommendationrun_events_pkey PRIMARY KEY (id);


--
-- Name: content_library_recommendationrun content_library_recommendationrun_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_recommendationrun
    ADD CONSTRAINT content_library_recommendationrun_pkey PRIMARY KEY (id);


--
-- Name: content_library_recommendationrunlog content_library_recommendationrunlog_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_recommendationrunlog
    ADD CONSTRAINT content_library_recommendationrunlog_pkey PRIMARY KEY (id);


--
-- Name: content_library_contentpersonalizationmodel content_library_recommendationsversion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentpersonalizationmodel
    ADD CONSTRAINT content_library_recommendationsversion_pkey PRIMARY KEY (id);


--
-- Name: content_library_renderedcreative content_library_rendered_content_block_id_creativ_28f5a099_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_renderedcreative
    ADD CONSTRAINT content_library_rendered_content_block_id_creativ_28f5a099_uniq UNIQUE (content_block_id, creative_id);


--
-- Name: content_library_renderedcreative content_library_renderedcreative_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_renderedcreative
    ADD CONSTRAINT content_library_renderedcreative_pkey PRIMARY KEY (id);


--
-- Name: content_library_rewardsmultiplier content_library_rewardsmultiplier_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_rewardsmultiplier
    ADD CONSTRAINT content_library_rewardsmultiplier_pkey PRIMARY KEY (id);


--
-- Name: content_library_salesforcemarketingcloudpublicationlist content_library_salesfor_client_id_name_ac7d20b2_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudpublicationlist
    ADD CONSTRAINT content_library_salesfor_client_id_name_ac7d20b2_uniq UNIQUE (client_id, name);


--
-- Name: content_library_salesforcemarketingcloudsuppressiondataexte91a1 content_library_salesfor_client_id_name_bc106f8d_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudsuppressiondataexte91a1
    ADD CONSTRAINT content_library_salesfor_client_id_name_bc106f8d_uniq UNIQUE (client_id, name);


--
-- Name: content_library_salesforcemarketingcloudintegration content_library_salesfor_client_id_subdomain_5518bc9d_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudintegration
    ADD CONSTRAINT content_library_salesfor_client_id_subdomain_5518bc9d_uniq UNIQUE (client_id, subdomain);


--
-- Name: content_library_salesforcemarketingcloudintegration content_library_salesfor_client_id_user_id_90e25568_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudintegration
    ADD CONSTRAINT content_library_salesfor_client_id_user_id_90e25568_uniq UNIQUE (client_id, user_id);


--
-- Name: content_library_salesforcemarketingcloudstaticcontentblockda7ea content_library_salesfor_content_block_id_asset_i_b3ddad8e_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudstaticcontentblockda7ea
    ADD CONSTRAINT content_library_salesfor_content_block_id_asset_i_b3ddad8e_uniq UNIQUE (content_block_id, asset_id);


--
-- Name: content_library_salesforcemarketingcloudcreativecontentblocaf9f content_library_salesfor_content_block_id_creativ_ef10a360_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudcreativecontentblocaf9f
    ADD CONSTRAINT content_library_salesfor_content_block_id_creativ_ef10a360_uniq UNIQUE (content_block_id, creative_id, asset_id);


--
-- Name: content_library_salesforcemarketingcloudcreativedocument content_library_salesfor_creative_id_document_typ_26c4c9a9_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudcreativedocument
    ADD CONSTRAINT content_library_salesfor_creative_id_document_typ_26c4c9a9_uniq UNIQUE (creative_id, document_type, asset_id);


--
-- Name: content_library_salesforcemarketingcloudcreativediscountoff3b11 content_library_salesfor_document_id_promotion_re_e92a4adf_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudcreativediscountoff3b11
    ADD CONSTRAINT content_library_salesfor_document_id_promotion_re_e92a4adf_uniq UNIQUE (document_id, promotion_redemption_id);


--
-- Name: content_library_salesforcemarketingcloudsend content_library_salesfor_event_id_send_id_2a2a4aef_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudsend
    ADD CONSTRAINT content_library_salesfor_event_id_send_id_2a2a4aef_uniq UNIQUE (event_id, send_id);


--
-- Name: content_library_salesforcemarketingcloud content_library_salesforcemarketingcloud_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloud
    ADD CONSTRAINT content_library_salesforcemarketingcloud_pkey PRIMARY KEY (emailserviceprovider_ptr_id);


--
-- Name: content_library_salesforcemarketingcloudcreativecontentblocaf9f content_library_salesforcemarketingcloudcreativecontentblo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudcreativecontentblocaf9f
    ADD CONSTRAINT content_library_salesforcemarketingcloudcreativecontentblo_pkey PRIMARY KEY (id);


--
-- Name: content_library_salesforcemarketingcloudcreativedocument content_library_salesforcemarketingcloudcreativedocument_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudcreativedocument
    ADD CONSTRAINT content_library_salesforcemarketingcloudcreativedocument_pkey PRIMARY KEY (id);


--
-- Name: content_library_salesforcemarketingcloudcreativediscountoff3b11 content_library_salesforcemarketingcloudcreativepromotiond_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudcreativediscountoff3b11
    ADD CONSTRAINT content_library_salesforcemarketingcloudcreativepromotiond_pkey PRIMARY KEY (id);


--
-- Name: content_library_salesforcemarketingcloudsend content_library_salesforcemarketingcloudeventmetadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudsend
    ADD CONSTRAINT content_library_salesforcemarketingcloudeventmetadata_pkey PRIMARY KEY (id);


--
-- Name: content_library_salesforcemarketingcloudintegration content_library_salesforcemarketingcloudintegration_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudintegration
    ADD CONSTRAINT content_library_salesforcemarketingcloudintegration_pkey PRIMARY KEY (id);


--
-- Name: content_library_salesforcemarketingcloudlinkmetadata content_library_salesforcemarketingcloudlinkmetadat_link_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudlinkmetadata
    ADD CONSTRAINT content_library_salesforcemarketingcloudlinkmetadat_link_id_key UNIQUE (link_id);


--
-- Name: content_library_salesforcemarketingcloudlinkmetadata content_library_salesforcemarketingcloudlinkmetadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudlinkmetadata
    ADD CONSTRAINT content_library_salesforcemarketingcloudlinkmetadata_pkey PRIMARY KEY (id);


--
-- Name: content_library_salesforcemarketingcloudmessagedeliveryconfig content_library_salesforcemarketingcloudmessagede_client_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudmessagedeliveryconfig
    ADD CONSTRAINT content_library_salesforcemarketingcloudmessagede_client_id_key UNIQUE (client_id);


--
-- Name: content_library_salesforcemarketingcloudmessagedeliveryconfig content_library_salesforcemarketingcloudmessagedeliverycon_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudmessagedeliveryconfig
    ADD CONSTRAINT content_library_salesforcemarketingcloudmessagedeliverycon_pkey PRIMARY KEY (id);


--
-- Name: content_library_salesforcemarketingcloudpublicationlist content_library_salesforcemarketingcloudpublicationlist_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudpublicationlist
    ADD CONSTRAINT content_library_salesforcemarketingcloudpublicationlist_pkey PRIMARY KEY (id);


--
-- Name: content_library_salesforcemarketingcloudsenderprofile content_library_salesforcemarketingcloudsenderprofile_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudsenderprofile
    ADD CONSTRAINT content_library_salesforcemarketingcloudsenderprofile_pkey PRIMARY KEY (id);


--
-- Name: content_library_salesforcemarketingcloudstaticcontentblockda7ea content_library_salesforcemarketingcloudstaticcontentblock_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudstaticcontentblockda7ea
    ADD CONSTRAINT content_library_salesforcemarketingcloudstaticcontentblock_pkey PRIMARY KEY (id);


--
-- Name: content_library_salesforcemarketingcloudsuppressiondataexte91a1 content_library_salesforcemarketingcloudsuppressiondataext_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudsuppressiondataexte91a1
    ADD CONSTRAINT content_library_salesforcemarketingcloudsuppressiondataext_pkey PRIMARY KEY (id);


--
-- Name: content_library_section content_library_section_event_id_final_position_9477b76e_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_section
    ADD CONSTRAINT content_library_section_event_id_final_position_9477b76e_uniq UNIQUE (event_id, final_position);


--
-- Name: content_library_section content_library_section_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_section
    ADD CONSTRAINT content_library_section_pkey PRIMARY KEY (id);


--
-- Name: content_library_senddatetimetreatment content_library_senddate_experiment_id_order_65411cda_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_senddatetimetreatment
    ADD CONSTRAINT content_library_senddate_experiment_id_order_65411cda_uniq UNIQUE (experiment_id, "order");


--
-- Name: content_library_senddatetimeexperiment content_library_senddatetimeexperiment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_senddatetimeexperiment
    ADD CONSTRAINT content_library_senddatetimeexperiment_pkey PRIMARY KEY (baseexperiment_ptr_id);


--
-- Name: content_library_senddatetimetreatment content_library_senddatetimetreatment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_senddatetimetreatment
    ADD CONSTRAINT content_library_senddatetimetreatment_pkey PRIMARY KEY (basetreatment_ptr_id);


--
-- Name: content_library_sendtimepersonalizationvariant content_library_sendtimepersonalizationvariant_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_sendtimepersonalizationvariant
    ADD CONSTRAINT content_library_sendtimepersonalizationvariant_pkey PRIMARY KEY (id);


--
-- Name: content_library_session content_library_session_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_session
    ADD CONSTRAINT content_library_session_pkey PRIMARY KEY (session_key);


--
-- Name: content_library_slice content_library_slice_image_id_key1; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_slice
    ADD CONSTRAINT content_library_slice_image_id_key1 UNIQUE (image_id);


--
-- Name: content_library_slice content_library_slice_link_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_slice
    ADD CONSTRAINT content_library_slice_link_id_key UNIQUE (link_id);


--
-- Name: content_library_slice content_library_slice_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_slice
    ADD CONSTRAINT content_library_slice_pkey PRIMARY KEY (id);


--
-- Name: content_library_staticaudiencemetadata content_library_staticau_audience_id_position_094a4a07_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_staticaudiencemetadata
    ADD CONSTRAINT content_library_staticau_audience_id_position_094a4a07_uniq UNIQUE (audience_id, "position");


--
-- Name: content_library_staticaudiencemetadata content_library_staticaudiencemetadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_staticaudiencemetadata
    ADD CONSTRAINT content_library_staticaudiencemetadata_pkey PRIMARY KEY (id);


--
-- Name: content_library_subjectline content_library_subjectline_creative_id_order_609cda13_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_subjectline
    ADD CONSTRAINT content_library_subjectline_creative_id_order_609cda13_uniq UNIQUE (creative_id, "order");


--
-- Name: content_library_subjectline content_library_subjectline_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_subjectline
    ADD CONSTRAINT content_library_subjectline_pkey PRIMARY KEY (id);


--
-- Name: content_library_tag content_library_tag_client_id_name_a8ceee86_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_tag
    ADD CONSTRAINT content_library_tag_client_id_name_a8ceee86_uniq UNIQUE (client_id, name);


--
-- Name: content_library_tag content_library_tag_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_tag
    ADD CONSTRAINT content_library_tag_pkey PRIMARY KEY (id);


--
-- Name: content_library_templatetreatment content_library_template_experiment_id_order_bc75d316_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_templatetreatment
    ADD CONSTRAINT content_library_template_experiment_id_order_bc75d316_uniq UNIQUE (experiment_id, "order");


--
-- Name: content_library_template content_library_template_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_template
    ADD CONSTRAINT content_library_template_pkey PRIMARY KEY (id);


--
-- Name: content_library_templatecontentblock content_library_template_template_id_position_076ecbb3_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_templatecontentblock
    ADD CONSTRAINT content_library_template_template_id_position_076ecbb3_uniq UNIQUE (template_id, "position") DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_templatetagchoice content_library_template_title_template_tag_id_7f15ee82_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_templatetagchoice
    ADD CONSTRAINT content_library_template_title_template_tag_id_7f15ee82_uniq UNIQUE (title, template_tag_id);


--
-- Name: content_library_templatecontentblock content_library_templatecontentblock_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_templatecontentblock
    ADD CONSTRAINT content_library_templatecontentblock_pkey PRIMARY KEY (id);


--
-- Name: content_library_templateexperiment content_library_templateexperiment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_templateexperiment
    ADD CONSTRAINT content_library_templateexperiment_pkey PRIMARY KEY (baseexperiment_ptr_id);


--
-- Name: content_library_templatetag content_library_templatetag_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_templatetag
    ADD CONSTRAINT content_library_templatetag_pkey PRIMARY KEY (id);


--
-- Name: content_library_templatetag content_library_templatetag_position_client_id_1b2af6f2_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_templatetag
    ADD CONSTRAINT content_library_templatetag_position_client_id_1b2af6f2_uniq UNIQUE ("position", client_id);


--
-- Name: content_library_templatetag content_library_templatetag_slug_client_id_b1aabcdb_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_templatetag
    ADD CONSTRAINT content_library_templatetag_slug_client_id_b1aabcdb_uniq UNIQUE (slug, client_id);


--
-- Name: content_library_templatetag content_library_templatetag_title_client_id_81672e2b_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_templatetag
    ADD CONSTRAINT content_library_templatetag_title_client_id_81672e2b_uniq UNIQUE (title, client_id);


--
-- Name: content_library_templatetagchoice content_library_templatetagchoice_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_templatetagchoice
    ADD CONSTRAINT content_library_templatetagchoice_pkey PRIMARY KEY (id);


--
-- Name: content_library_templatetreatment content_library_templatetreatment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_templatetreatment
    ADD CONSTRAINT content_library_templatetreatment_pkey PRIMARY KEY (basetreatment_ptr_id);


--
-- Name: content_library_templatevariant content_library_templatevariant_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_templatevariant
    ADD CONSTRAINT content_library_templatevariant_pkey PRIMARY KEY (id);


--
-- Name: content_library_trackingparameter content_library_tracking_client_id_level_position_98cd02b2_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_trackingparameter
    ADD CONSTRAINT content_library_tracking_client_id_level_position_98cd02b2_uniq UNIQUE (client_id, level, "position");


--
-- Name: content_library_trackingparameter content_library_tracking_client_id_level_slug_96200cbd_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_trackingparameter
    ADD CONSTRAINT content_library_tracking_client_id_level_slug_96200cbd_uniq UNIQUE (client_id, level, slug);


--
-- Name: content_library_trackingparameterchoice content_library_tracking_tracking_parameter_id_ti_cdb787b7_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_trackingparameterchoice
    ADD CONSTRAINT content_library_tracking_tracking_parameter_id_ti_cdb787b7_uniq UNIQUE (tracking_parameter_id, title);


--
-- Name: content_library_trackingparameter content_library_trackingparameter_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_trackingparameter
    ADD CONSTRAINT content_library_trackingparameter_pkey PRIMARY KEY (id);


--
-- Name: content_library_trackingparameterchoice content_library_trackingparameterchoice_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_trackingparameterchoice
    ADD CONSTRAINT content_library_trackingparameterchoice_pkey PRIMARY KEY (id);


--
-- Name: content_library_user content_library_user_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_user
    ADD CONSTRAINT content_library_user_email_key UNIQUE (email);


--
-- Name: content_library_user_groups content_library_user_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_user_groups
    ADD CONSTRAINT content_library_user_groups_pkey PRIMARY KEY (id);


--
-- Name: content_library_user_groups content_library_user_groups_user_id_group_id_6d2d1084_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_user_groups
    ADD CONSTRAINT content_library_user_groups_user_id_group_id_6d2d1084_uniq UNIQUE (user_id, group_id);


--
-- Name: content_library_user content_library_user_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_user
    ADD CONSTRAINT content_library_user_pkey PRIMARY KEY (id);


--
-- Name: content_library_user_user_permissions content_library_user_use_user_id_permission_id_36abb9e2_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_user_user_permissions
    ADD CONSTRAINT content_library_user_use_user_id_permission_id_36abb9e2_uniq UNIQUE (user_id, permission_id);


--
-- Name: content_library_user_user_permissions content_library_user_user_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_user_user_permissions
    ADD CONSTRAINT content_library_user_user_permissions_pkey PRIMARY KEY (id);


--
-- Name: content_library_availability creative_exclude_gist_constraint; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_availability
    ADD CONSTRAINT creative_exclude_gist_constraint EXCLUDE USING gist (creative_id WITH =, start_end_datetime WITH &&) DEFERRABLE;


--
-- Name: django_admin_log django_admin_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_pkey PRIMARY KEY (id);


--
-- Name: django_celery_beat_clockedschedule django_celery_beat_clockedschedule_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_celery_beat_clockedschedule
    ADD CONSTRAINT django_celery_beat_clockedschedule_pkey PRIMARY KEY (id);


--
-- Name: django_celery_beat_crontabschedule django_celery_beat_crontabschedule_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_celery_beat_crontabschedule
    ADD CONSTRAINT django_celery_beat_crontabschedule_pkey PRIMARY KEY (id);


--
-- Name: django_celery_beat_intervalschedule django_celery_beat_intervalschedule_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_celery_beat_intervalschedule
    ADD CONSTRAINT django_celery_beat_intervalschedule_pkey PRIMARY KEY (id);


--
-- Name: django_celery_beat_periodictask django_celery_beat_periodictask_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_celery_beat_periodictask
    ADD CONSTRAINT django_celery_beat_periodictask_name_key UNIQUE (name);


--
-- Name: django_celery_beat_periodictask django_celery_beat_periodictask_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_celery_beat_periodictask
    ADD CONSTRAINT django_celery_beat_periodictask_pkey PRIMARY KEY (id);


--
-- Name: django_celery_beat_periodictasks django_celery_beat_periodictasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_celery_beat_periodictasks
    ADD CONSTRAINT django_celery_beat_periodictasks_pkey PRIMARY KEY (ident);


--
-- Name: django_celery_beat_solarschedule django_celery_beat_solar_event_latitude_longitude_ba64999a_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_celery_beat_solarschedule
    ADD CONSTRAINT django_celery_beat_solar_event_latitude_longitude_ba64999a_uniq UNIQUE (event, latitude, longitude);


--
-- Name: django_celery_beat_solarschedule django_celery_beat_solarschedule_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_celery_beat_solarschedule
    ADD CONSTRAINT django_celery_beat_solarschedule_pkey PRIMARY KEY (id);


--
-- Name: django_content_type django_content_type_app_label_model_76bd3d3b_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq UNIQUE (app_label, model);


--
-- Name: django_content_type django_content_type_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_pkey PRIMARY KEY (id);


--
-- Name: django_migrations django_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_migrations
    ADD CONSTRAINT django_migrations_pkey PRIMARY KEY (id);


--
-- Name: django_session django_session_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_session
    ADD CONSTRAINT django_session_pkey PRIMARY KEY (session_key);


--
-- Name: django_site django_site_domain_a2e37b91_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_site
    ADD CONSTRAINT django_site_domain_a2e37b91_uniq UNIQUE (domain);


--
-- Name: django_site django_site_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_site
    ADD CONSTRAINT django_site_pkey PRIMARY KEY (id);


--
-- Name: content_library_eventaudience eventaudience_priority_uniqueness; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventaudience
    ADD CONSTRAINT eventaudience_priority_uniqueness UNIQUE (event_id, priority, audience_type) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: oauth2_provider_accesstoken oauth2_provider_accesstoken_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth2_provider_accesstoken
    ADD CONSTRAINT oauth2_provider_accesstoken_pkey PRIMARY KEY (id);


--
-- Name: oauth2_provider_accesstoken oauth2_provider_accesstoken_token_8af090f8_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth2_provider_accesstoken
    ADD CONSTRAINT oauth2_provider_accesstoken_token_8af090f8_uniq UNIQUE (token);


--
-- Name: oauth2_provider_grant oauth2_provider_grant_code_49ab4ddf_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth2_provider_grant
    ADD CONSTRAINT oauth2_provider_grant_code_49ab4ddf_uniq UNIQUE (code);


--
-- Name: oauth2_provider_grant oauth2_provider_grant_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth2_provider_grant
    ADD CONSTRAINT oauth2_provider_grant_pkey PRIMARY KEY (id);


--
-- Name: oauth2_provider_refreshtoken oauth2_provider_refreshtoken_access_token_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth2_provider_refreshtoken
    ADD CONSTRAINT oauth2_provider_refreshtoken_access_token_id_key UNIQUE (access_token_id);


--
-- Name: oauth2_provider_refreshtoken oauth2_provider_refreshtoken_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth2_provider_refreshtoken
    ADD CONSTRAINT oauth2_provider_refreshtoken_pkey PRIMARY KEY (id);


--
-- Name: oauth2_provider_refreshtoken oauth2_provider_refreshtoken_token_d090daa4_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth2_provider_refreshtoken
    ADD CONSTRAINT oauth2_provider_refreshtoken_token_d090daa4_uniq UNIQUE (token);


--
-- Name: organizations_organizationuser organizations_organizati_user_id_organization_id_dd2bc761_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations_organizationuser
    ADD CONSTRAINT organizations_organizati_user_id_organization_id_dd2bc761_uniq UNIQUE (user_id, organization_id);


--
-- Name: organizations_organization organizations_organization_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations_organization
    ADD CONSTRAINT organizations_organization_pkey PRIMARY KEY (id);


--
-- Name: organizations_organization organizations_organization_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations_organization
    ADD CONSTRAINT organizations_organization_slug_key UNIQUE (slug);


--
-- Name: organizations_organizationowner organizations_organizationowner_organization_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations_organizationowner
    ADD CONSTRAINT organizations_organizationowner_organization_id_key UNIQUE (organization_id);


--
-- Name: organizations_organizationowner organizations_organizationowner_organization_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations_organizationowner
    ADD CONSTRAINT organizations_organizationowner_organization_user_id_key UNIQUE (organization_user_id);


--
-- Name: organizations_organizationowner organizations_organizationowner_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations_organizationowner
    ADD CONSTRAINT organizations_organizationowner_pkey PRIMARY KEY (id);


--
-- Name: organizations_organizationuser organizations_organizationuser_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations_organizationuser
    ADD CONSTRAINT organizations_organizationuser_pkey PRIMARY KEY (id);


--
-- Name: content_library_promotionredemption promotion_redemption_exclude_gist_constraint; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_promotionredemption
    ADD CONSTRAINT promotion_redemption_exclude_gist_constraint EXCLUDE USING gist (promotion_id WITH =, start_end_datetime WITH &&) DEFERRABLE;


--
-- Name: content_library_senddatetime senddatetime_exclude_gist_constraint; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_senddatetime
    ADD CONSTRAINT senddatetime_exclude_gist_constraint EXCLUDE USING gist (send_time_personalization_variant_id WITH =, send_datetime_range WITH &&) DEFERRABLE;


--
-- Name: account_emailaddress_email_03be32b2_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX account_emailaddress_email_03be32b2_like ON public.account_emailaddress USING btree (email varchar_pattern_ops);


--
-- Name: account_emailaddress_user_id_2c513194; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX account_emailaddress_user_id_2c513194 ON public.account_emailaddress USING btree (user_id);


--
-- Name: account_emailconfirmation_email_address_id_5b7f8c58; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX account_emailconfirmation_email_address_id_5b7f8c58 ON public.account_emailconfirmation USING btree (email_address_id);


--
-- Name: account_emailconfirmation_key_f43612bd_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX account_emailconfirmation_key_f43612bd_like ON public.account_emailconfirmation USING btree (key varchar_pattern_ops);


--
-- Name: auth_group_name_a6ea08ec_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auth_group_name_a6ea08ec_like ON public.auth_group USING btree (name varchar_pattern_ops);


--
-- Name: auth_group_permissions_group_id_b120cbf9; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auth_group_permissions_group_id_b120cbf9 ON public.auth_group_permissions USING btree (group_id);


--
-- Name: auth_group_permissions_permission_id_84c5c92e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auth_group_permissions_permission_id_84c5c92e ON public.auth_group_permissions USING btree (permission_id);


--
-- Name: auth_permission_content_type_id_2f476e4b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auth_permission_content_type_id_2f476e4b ON public.auth_permission USING btree (content_type_id);


--
-- Name: content_lib__attrib_43a12a_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_lib__attrib_43a12a_gin ON public.content_library_creative USING gin (_attributes);


--
-- Name: content_lib_descrip_f5b382_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_lib_descrip_f5b382_idx ON public.content_library_productvalue USING btree (description);


--
-- Name: content_lib_externa_a4b479_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_lib_externa_a4b479_idx ON public.content_library_productvalue USING btree (external_id);


--
-- Name: content_lib_id_fiel_ed4230_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_lib_id_fiel_ed4230_idx ON public.content_library_productfield USING btree (id_field_name);


--
-- Name: content_lib_positio_ad7258_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_lib_positio_ad7258_idx ON public.content_library_productfield USING btree ("position");


--
-- Name: content_lib_send_da_6c4b6c_gist; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_lib_send_da_6c4b6c_gist ON public.content_library_senddatetime USING gist (send_datetime_range);


--
-- Name: content_lib_start_e_55f6d4_gist; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_lib_start_e_55f6d4_gist ON public.content_library_promotionredemption USING gist (start_end_datetime);


--
-- Name: content_lib_start_e_7b73d0_gist; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_lib_start_e_7b73d0_gist ON public.content_library_availability USING gist (start_end_datetime);


--
-- Name: content_library_acousticca_acoustic_campaign_id_53f8a80c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_acousticca_acoustic_campaign_id_53f8a80c ON public.content_library_acousticcampaignlinkmetadata USING btree (acoustic_campaign_id);


--
-- Name: content_library_acousticca_created_by_id_10840009; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_acousticca_created_by_id_10840009 ON public.content_library_acousticcampaignfromaddress USING btree (created_by_id);


--
-- Name: content_library_acousticca_created_by_id_12437f85; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_acousticca_created_by_id_12437f85 ON public.content_library_acousticcampaigndynamiccontent USING btree (created_by_id);


--
-- Name: content_library_acousticca_section_id_2bf1459b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_acousticca_section_id_2bf1459b ON public.content_library_acousticcampaigndynamiccontent USING btree (section_id);


--
-- Name: content_library_acousticca_updated_by_id_367c635e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_acousticca_updated_by_id_367c635e ON public.content_library_acousticcampaignfromaddress USING btree (updated_by_id);


--
-- Name: content_library_acousticca_updated_by_id_c608ce1a; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_acousticca_updated_by_id_c608ce1a ON public.content_library_acousticcampaigndynamiccontent USING btree (updated_by_id);


--
-- Name: content_library_acousticcampaignfromaddress_client_id_d5e48ee0; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_acousticcampaignfromaddress_client_id_d5e48ee0 ON public.content_library_acousticcampaignfromaddress USING btree (client_id);


--
-- Name: content_library_acousticcampaignfromname_client_id_cd8a54e2; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_acousticcampaignfromname_client_id_cd8a54e2 ON public.content_library_acousticcampaignfromname USING btree (client_id);


--
-- Name: content_library_acousticcampaignfromname_created_by_id_61a3eebe; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_acousticcampaignfromname_created_by_id_61a3eebe ON public.content_library_acousticcampaignfromname USING btree (created_by_id);


--
-- Name: content_library_acousticcampaignfromname_updated_by_id_73e0caf1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_acousticcampaignfromname_updated_by_id_73e0caf1 ON public.content_library_acousticcampaignfromname USING btree (updated_by_id);


--
-- Name: content_library_acousticcampaignmailing_created_by_id_23cc41cc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_acousticcampaignmailing_created_by_id_23cc41cc ON public.content_library_acousticcampaignmailing USING btree (created_by_id);


--
-- Name: content_library_acousticcampaignmailing_event_id_73b2d0d2; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_acousticcampaignmailing_event_id_73b2d0d2 ON public.content_library_acousticcampaignmailing USING btree (event_id);


--
-- Name: content_library_acousticcampaignmailing_updated_by_id_33f7b787; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_acousticcampaignmailing_updated_by_id_33f7b787 ON public.content_library_acousticcampaignmailing USING btree (updated_by_id);


--
-- Name: content_library_acousticcampaignreplyto_client_id_d6f246d4; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_acousticcampaignreplyto_client_id_d6f246d4 ON public.content_library_acousticcampaignreplyto USING btree (client_id);


--
-- Name: content_library_acousticcampaignreplyto_created_by_id_85fdec87; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_acousticcampaignreplyto_created_by_id_85fdec87 ON public.content_library_acousticcampaignreplyto USING btree (created_by_id);


--
-- Name: content_library_acousticcampaignreplyto_updated_by_id_6d503bb0; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_acousticcampaignreplyto_updated_by_id_6d503bb0 ON public.content_library_acousticcampaignreplyto USING btree (updated_by_id);


--
-- Name: content_library_adhoctreatment_experiment_id_a6d26b0b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_adhoctreatment_experiment_id_a6d26b0b ON public.content_library_adhoctreatment USING btree (experiment_id);


--
-- Name: content_library_adhocvaria_adhoctreatment_id_066394b4; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_adhocvaria_adhoctreatment_id_066394b4 ON public.content_library_adhocvariant_treatments USING btree (adhoctreatment_id);


--
-- Name: content_library_adhocvaria_adhocvariant_id_85208f50; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_adhocvaria_adhocvariant_id_85208f50 ON public.content_library_adhocvariant_treatments USING btree (adhocvariant_id);


--
-- Name: content_library_adhocvariant_created_by_id_71cb08db; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_adhocvariant_created_by_id_71cb08db ON public.content_library_adhocvariant USING btree (created_by_id);


--
-- Name: content_library_adhocvariant_event_id_3461cff0; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_adhocvariant_event_id_3461cff0 ON public.content_library_adhocvariant USING btree (event_id);


--
-- Name: content_library_adhocvariant_updated_by_id_60287550; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_adhocvariant_updated_by_id_60287550 ON public.content_library_adhocvariant USING btree (updated_by_id);


--
-- Name: content_library_adobecampa_created_by_id_007bd27e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_adobecampa_created_by_id_007bd27e ON public.content_library_adobecampaigneventmetadata USING btree (created_by_id);


--
-- Name: content_library_adobecampa_updated_by_id_19f8b486; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_adobecampa_updated_by_id_19f8b486 ON public.content_library_adobecampaigneventmetadata USING btree (updated_by_id);


--
-- Name: content_library_adobecampaigneventmetadata_event_id_0f48fa59; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_adobecampaigneventmetadata_event_id_0f48fa59 ON public.content_library_adobecampaigneventmetadata USING btree (event_id);


--
-- Name: content_library_application_client_id_e455f9bc_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_application_client_id_e455f9bc_like ON public.content_library_application USING btree (client_id varchar_pattern_ops);


--
-- Name: content_library_application_client_secret_55d0fe31; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_application_client_secret_55d0fe31 ON public.content_library_application USING btree (client_secret);


--
-- Name: content_library_application_cp_client_id_abb31c95; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_application_cp_client_id_abb31c95 ON public.content_library_application USING btree (cp_client_id);


--
-- Name: content_library_application_user_id_8c388a30; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_application_user_id_8c388a30 ON public.content_library_application USING btree (user_id);


--
-- Name: content_library_audiencefilter_client_id_fecea3f3; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_audiencefilter_client_id_fecea3f3 ON public.content_library_audience USING btree (client_id);


--
-- Name: content_library_audiencefilter_created_by_id_f353e83a; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_audiencefilter_created_by_id_f353e83a ON public.content_library_audience USING btree (created_by_id);


--
-- Name: content_library_audiencefilter_updated_by_id_a9b392d7; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_audiencefilter_updated_by_id_a9b392d7 ON public.content_library_audience USING btree (updated_by_id);


--
-- Name: content_library_availability_created_by_id_0634f66c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_availability_created_by_id_0634f66c ON public.content_library_availability USING btree (created_by_id);


--
-- Name: content_library_availability_creative_id_b53939b3; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_availability_creative_id_b53939b3 ON public.content_library_availability USING btree (creative_id);


--
-- Name: content_library_availability_updated_by_id_dee8ab29; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_availability_updated_by_id_dee8ab29 ON public.content_library_availability USING btree (updated_by_id);


--
-- Name: content_library_availablep_availableproductcollection_68f6f7e5; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_availablep_availableproductcollection_68f6f7e5 ON public.content_library_availableproductcollection_product_values USING btree (availableproductcollection_id);


--
-- Name: content_library_availablep_created_by_id_e00a14f2; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_availablep_created_by_id_e00a14f2 ON public.content_library_availableproductcollection USING btree (created_by_id);


--
-- Name: content_library_availablep_productvalue_id_3c683ec0; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_availablep_productvalue_id_3c683ec0 ON public.content_library_availableproductcollection_product_values USING btree (productvalue_id);


--
-- Name: content_library_availablep_updated_by_id_6ed41dd6; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_availablep_updated_by_id_6ed41dd6 ON public.content_library_availableproductcollection USING btree (updated_by_id);


--
-- Name: content_library_baseexperiment_client_id_4c17d4cb; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_baseexperiment_client_id_4c17d4cb ON public.content_library_baseexperiment USING btree (client_id);


--
-- Name: content_library_baseexperiment_created_by_id_d1a493fa; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_baseexperiment_created_by_id_d1a493fa ON public.content_library_baseexperiment USING btree (created_by_id);


--
-- Name: content_library_baseexperiment_polymorphic_ctype_id_48130268; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_baseexperiment_polymorphic_ctype_id_48130268 ON public.content_library_baseexperiment USING btree (polymorphic_ctype_id);


--
-- Name: content_library_baseexperiment_updated_by_id_4624af0c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_baseexperiment_updated_by_id_4624af0c ON public.content_library_baseexperiment USING btree (updated_by_id);


--
-- Name: content_library_basetemplate_body_id_0a5bd0dd; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_basetemplate_body_id_0a5bd0dd ON public.content_library_basetemplate USING btree (body_id);


--
-- Name: content_library_basetemplate_client_id_10d6847d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_basetemplate_client_id_10d6847d ON public.content_library_basetemplate USING btree (client_id);


--
-- Name: content_library_basetemplate_created_by_id_27245109; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_basetemplate_created_by_id_27245109 ON public.content_library_basetemplate USING btree (created_by_id);


--
-- Name: content_library_basetemplate_updated_by_id_cac39035; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_basetemplate_updated_by_id_cac39035 ON public.content_library_basetemplate USING btree (updated_by_id);


--
-- Name: content_library_basetreatment_created_by_id_ce86479f; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_basetreatment_created_by_id_ce86479f ON public.content_library_basetreatment USING btree (created_by_id);


--
-- Name: content_library_basetreatment_polymorphic_ctype_id_4ebcfb5a; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_basetreatment_polymorphic_ctype_id_4ebcfb5a ON public.content_library_basetreatment USING btree (polymorphic_ctype_id);


--
-- Name: content_library_basetreatment_updated_by_id_3e963391; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_basetreatment_updated_by_id_3e963391 ON public.content_library_basetreatment USING btree (updated_by_id);


--
-- Name: content_library_bodytempla_body_template_id_8dcb42fe; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_bodytempla_body_template_id_8dcb42fe ON public.content_library_bodytemplatecontentblock USING btree (body_template_id);


--
-- Name: content_library_bodytempla_content_block_id_a903e2c2; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_bodytempla_content_block_id_a903e2c2 ON public.content_library_bodytemplatecontentblock USING btree (content_block_id);


--
-- Name: content_library_bodytemplate_base_template_id_4c64ec4c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_bodytemplate_base_template_id_4c64ec4c ON public.content_library_bodytemplate USING btree (base_template_id);


--
-- Name: content_library_bodytemplate_body_id_38841aae; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_bodytemplate_body_id_38841aae ON public.content_library_bodytemplate USING btree (body_id);


--
-- Name: content_library_cheetahdig_cheetah_digital_id_746d0616; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_cheetahdig_cheetah_digital_id_746d0616 ON public.content_library_cheetahdigitallinkmetadata USING btree (cheetah_digital_id);


--
-- Name: content_library_cheetahdig_content_block_id_4eeb2028; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_cheetahdig_content_block_id_4eeb2028 ON public.content_library_cheetahdigitalstaticcontentblockdocument USING btree (content_block_id);


--
-- Name: content_library_cheetahdig_content_block_id_5bcc3779; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_cheetahdig_content_block_id_5bcc3779 ON public.content_library_cheetahdigitalcreativecontentblockdocument USING btree (content_block_id);


--
-- Name: content_library_cheetahdig_created_by_id_293cb33b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_cheetahdig_created_by_id_293cb33b ON public.content_library_cheetahdigitalclientconfig USING btree (created_by_id);


--
-- Name: content_library_cheetahdig_created_by_id_2ae1fc72; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_cheetahdig_created_by_id_2ae1fc72 ON public.content_library_cheetahdigitalcreativedocument USING btree (created_by_id);


--
-- Name: content_library_cheetahdig_created_by_id_32bbfa7d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_cheetahdig_created_by_id_32bbfa7d ON public.content_library_cheetahdigitaleventmetadata USING btree (created_by_id);


--
-- Name: content_library_cheetahdig_created_by_id_4f9c07bb; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_cheetahdig_created_by_id_4f9c07bb ON public.content_library_cheetahdigitalcreativecontentblockdocument USING btree (created_by_id);


--
-- Name: content_library_cheetahdig_created_by_id_804fdccc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_cheetahdig_created_by_id_804fdccc ON public.content_library_cheetahdigitalstaticcontentblockdocument USING btree (created_by_id);


--
-- Name: content_library_cheetahdig_created_by_id_e8c5fedf; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_cheetahdig_created_by_id_e8c5fedf ON public.content_library_cheetahdigitalcreativediscountofferdocument USING btree (created_by_id);


--
-- Name: content_library_cheetahdig_creative_id_0ee786fa; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_cheetahdig_creative_id_0ee786fa ON public.content_library_cheetahdigitalcreativedocument USING btree (creative_id);


--
-- Name: content_library_cheetahdig_creative_id_c2e65ce8; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_cheetahdig_creative_id_c2e65ce8 ON public.content_library_cheetahdigitalcreativecontentblockdocument USING btree (creative_id);


--
-- Name: content_library_cheetahdig_document_id_9305a09d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_cheetahdig_document_id_9305a09d ON public.content_library_cheetahdigitalcreativediscountofferdocument USING btree (document_id);


--
-- Name: content_library_cheetahdig_promotion_redemption_id_1039038b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_cheetahdig_promotion_redemption_id_1039038b ON public.content_library_cheetahdigitalcreativediscountofferdocument USING btree (promotion_redemption_id);


--
-- Name: content_library_cheetahdig_updated_by_id_0d4f8a79; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_cheetahdig_updated_by_id_0d4f8a79 ON public.content_library_cheetahdigitalstaticcontentblockdocument USING btree (updated_by_id);


--
-- Name: content_library_cheetahdig_updated_by_id_19a63dae; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_cheetahdig_updated_by_id_19a63dae ON public.content_library_cheetahdigitalcreativecontentblockdocument USING btree (updated_by_id);


--
-- Name: content_library_cheetahdig_updated_by_id_4ad0bcf0; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_cheetahdig_updated_by_id_4ad0bcf0 ON public.content_library_cheetahdigitaleventmetadata USING btree (updated_by_id);


--
-- Name: content_library_cheetahdig_updated_by_id_6d2050e8; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_cheetahdig_updated_by_id_6d2050e8 ON public.content_library_cheetahdigitalcreativedocument USING btree (updated_by_id);


--
-- Name: content_library_cheetahdig_updated_by_id_7138475f; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_cheetahdig_updated_by_id_7138475f ON public.content_library_cheetahdigitalcreativediscountofferdocument USING btree (updated_by_id);


--
-- Name: content_library_cheetahdig_updated_by_id_754663b2; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_cheetahdig_updated_by_id_754663b2 ON public.content_library_cheetahdigitalclientconfig USING btree (updated_by_id);


--
-- Name: content_library_cheetahdigital_client_id_3ed08f58; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_cheetahdigital_client_id_3ed08f58 ON public.content_library_cheetahdigital USING btree (client_id);


--
-- Name: content_library_cheetahdigital_client_id_3ed08f58_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_cheetahdigital_client_id_3ed08f58_like ON public.content_library_cheetahdigital USING btree (client_id varchar_pattern_ops);


--
-- Name: content_library_cheetahdigital_consumer_key_0a933464; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_cheetahdigital_consumer_key_0a933464 ON public.content_library_cheetahdigital USING btree (consumer_key);


--
-- Name: content_library_cheetahdigital_consumer_key_0a933464_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_cheetahdigital_consumer_key_0a933464_like ON public.content_library_cheetahdigital USING btree (consumer_key varchar_pattern_ops);


--
-- Name: content_library_cheetahdigital_consumer_secret_750c0993; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_cheetahdigital_consumer_secret_750c0993 ON public.content_library_cheetahdigital USING btree (consumer_secret);


--
-- Name: content_library_cheetahdigital_customer_id_ca7caf4e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_cheetahdigital_customer_id_ca7caf4e ON public.content_library_cheetahdigital USING btree (customer_id);


--
-- Name: content_library_cheetahdigital_customer_id_ca7caf4e_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_cheetahdigital_customer_id_ca7caf4e_like ON public.content_library_cheetahdigital USING btree (customer_id varchar_pattern_ops);


--
-- Name: content_library_cheetahdigitaleventmetadata_event_id_b6bac470; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_cheetahdigitaleventmetadata_event_id_b6bac470 ON public.content_library_cheetahdigitaleventmetadata USING btree (event_id);


--
-- Name: content_library_client_name_84ba91bb_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_client_name_84ba91bb_like ON public.content_library_client USING btree (name varchar_pattern_ops);


--
-- Name: content_library_clientconf_default_content_personaliz_962b05a4; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_clientconf_default_content_personaliz_962b05a4 ON public.content_library_clientconfiguration USING btree (default_content_personalization_model_id);


--
-- Name: content_library_clientconfiguration_created_by_id_e185001a; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_clientconfiguration_created_by_id_e185001a ON public.content_library_clientconfiguration USING btree (created_by_id);


--
-- Name: content_library_clientconfiguration_updated_by_id_77b2e3f8; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_clientconfiguration_updated_by_id_77b2e3f8 ON public.content_library_clientconfiguration USING btree (updated_by_id);


--
-- Name: content_library_clientreuserule_created_by_id_6de36490; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_clientreuserule_created_by_id_6de36490 ON public.content_library_clientreuserule USING btree (created_by_id);


--
-- Name: content_library_clientreuserule_updated_by_id_cde56579; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_clientreuserule_updated_by_id_cde56579 ON public.content_library_clientreuserule USING btree (updated_by_id);


--
-- Name: content_library_clientuser_organization_id_0fc260a3; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_clientuser_organization_id_0fc260a3 ON public.content_library_clientuser USING btree (organization_id);


--
-- Name: content_library_clientuser_user_id_e884f9ba; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_clientuser_user_id_e884f9ba ON public.content_library_clientuser USING btree (user_id);


--
-- Name: content_library_contentblo_content_block_id_10afc397; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_contentblo_content_block_id_10afc397 ON public.content_library_contentblocktemplatetag USING btree (content_block_id);


--
-- Name: content_library_contentblo_content_block_id_b51353ee; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_contentblo_content_block_id_b51353ee ON public.content_library_contentblockcreativeversion USING btree (content_block_id);


--
-- Name: content_library_contentblo_creative_id_24aa3d04; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_contentblo_creative_id_24aa3d04 ON public.content_library_contentblockcreativeversion USING btree (creative_id);


--
-- Name: content_library_contentblo_template_tag_id_60a5d5e8; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_contentblo_template_tag_id_60a5d5e8 ON public.content_library_contentblocktemplatetag USING btree (template_tag_id);


--
-- Name: content_library_contentblock_client_id_c57b1221; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_contentblock_client_id_c57b1221 ON public.content_library_contentblock USING btree (client_id);


--
-- Name: content_library_contentblock_created_by_id_09923cb6; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_contentblock_created_by_id_09923cb6 ON public.content_library_contentblock USING btree (created_by_id);


--
-- Name: content_library_contentblock_html_bundle_id_3eaf9d2b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_contentblock_html_bundle_id_3eaf9d2b ON public.content_library_contentblock USING btree (html_bundle_id);


--
-- Name: content_library_contentblock_slug_fed59a16; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_contentblock_slug_fed59a16 ON public.content_library_contentblock USING btree (slug);


--
-- Name: content_library_contentblock_slug_fed59a16_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_contentblock_slug_fed59a16_like ON public.content_library_contentblock USING btree (slug varchar_pattern_ops);


--
-- Name: content_library_contentblock_updated_by_id_0b31637e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_contentblock_updated_by_id_0b31637e ON public.content_library_contentblock USING btree (updated_by_id);


--
-- Name: content_library_contentblocktemplatetag_created_by_id_2bf7c376; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_contentblocktemplatetag_created_by_id_2bf7c376 ON public.content_library_contentblocktemplatetag USING btree (created_by_id);


--
-- Name: content_library_contentblocktemplatetag_updated_by_id_0cdc89d4; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_contentblocktemplatetag_updated_by_id_0cdc89d4 ON public.content_library_contentblocktemplatetag USING btree (updated_by_id);


--
-- Name: content_library_contentper_content_personalization_mo_5fb658c3; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_contentper_content_personalization_mo_5fb658c3 ON public.content_library_contentpersonalizationmodeltreatment USING btree (content_personalization_model_id);


--
-- Name: content_library_contentper_created_by_id_430a3f8a; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_contentper_created_by_id_430a3f8a ON public.content_library_contentpersonalizationmodelvariant USING btree (created_by_id);


--
-- Name: content_library_contentper_event_id_cc121f91; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_contentper_event_id_cc121f91 ON public.content_library_contentpersonalizationmodelvariant USING btree (event_id);


--
-- Name: content_library_contentper_experiment_id_7467bf9b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_contentper_experiment_id_7467bf9b ON public.content_library_contentpersonalizationmodeltreatment USING btree (experiment_id);


--
-- Name: content_library_contentper_model_id_8ba8fc24; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_contentper_model_id_8ba8fc24 ON public.content_library_contentpersonalizationmodelvariant USING btree (model_id);


--
-- Name: content_library_contentper_treatment_id_01fd4288; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_contentper_treatment_id_01fd4288 ON public.content_library_contentpersonalizationmodelvariant USING btree (treatment_id);


--
-- Name: content_library_contentper_updated_by_id_ba1c93d1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_contentper_updated_by_id_ba1c93d1 ON public.content_library_contentpersonalizationmodelvariant USING btree (updated_by_id);


--
-- Name: content_library_creative_audience_filter_id_b976cd49; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_creative_audience_filter_id_b976cd49 ON public.content_library_creative USING btree (audience_id);


--
-- Name: content_library_creative_client_id_b4c971f8; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_creative_client_id_b4c971f8 ON public.content_library_creative USING btree (client_id);


--
-- Name: content_library_creative_created_by_id_d13c712e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_creative_created_by_id_d13c712e ON public.content_library_creative USING btree (created_by_id);


--
-- Name: content_library_creative_p_creative_id_eac423c0; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_creative_p_creative_id_eac423c0 ON public.content_library_creative_product_collections USING btree (creative_id);


--
-- Name: content_library_creative_p_from_creative_id_e4167acb; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_creative_p_from_creative_id_e4167acb ON public.content_library_creative_prohibited_creatives USING btree (from_creative_id);


--
-- Name: content_library_creative_p_productcollection_id_0ebdd079; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_creative_p_productcollection_id_0ebdd079 ON public.content_library_creative_product_collections USING btree (productcollection_id);


--
-- Name: content_library_creative_p_to_creative_id_6450fc1b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_creative_p_to_creative_id_6450fc1b ON public.content_library_creative_prohibited_creatives USING btree (to_creative_id);


--
-- Name: content_library_creative_short_uuid_08266be6; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_creative_short_uuid_08266be6 ON public.content_library_creative USING btree (short_uuid);


--
-- Name: content_library_creative_short_uuid_08266be6_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_creative_short_uuid_08266be6_like ON public.content_library_creative USING btree (short_uuid varchar_pattern_ops);


--
-- Name: content_library_creative_slug_d20de054; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_creative_slug_d20de054 ON public.content_library_creative USING btree (slug);


--
-- Name: content_library_creative_slug_d20de054_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_creative_slug_d20de054_like ON public.content_library_creative USING btree (slug varchar_pattern_ops);


--
-- Name: content_library_creative_status_ce9eece5; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_creative_status_ce9eece5 ON public.content_library_creative USING btree (status);


--
-- Name: content_library_creative_tags_creative_id_3f790aa3; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_creative_tags_creative_id_3f790aa3 ON public.content_library_creative_tags USING btree (creative_id);


--
-- Name: content_library_creative_tags_tag_id_1dca22ca; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_creative_tags_tag_id_1dca22ca ON public.content_library_creative_tags USING btree (tag_id);


--
-- Name: content_library_creative_title_c42d6562; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_creative_title_c42d6562 ON public.content_library_creative USING btree (title);


--
-- Name: content_library_creative_title_c42d6562_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_creative_title_c42d6562_like ON public.content_library_creative USING btree (title varchar_pattern_ops);


--
-- Name: content_library_creative_updated_by_id_f5a8281d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_creative_updated_by_id_f5a8281d ON public.content_library_creative USING btree (updated_by_id);


--
-- Name: content_library_creativeattribute_client_id_42e16f4e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_creativeattribute_client_id_42e16f4e ON public.content_library_creativeattribute USING btree (client_id);


--
-- Name: content_library_creativeattribute_created_by_id_45c48e6f; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_creativeattribute_created_by_id_45c48e6f ON public.content_library_creativeattribute USING btree (created_by_id);


--
-- Name: content_library_creativeattribute_slug_34d734e6; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_creativeattribute_slug_34d734e6 ON public.content_library_creativeattribute USING btree (slug);


--
-- Name: content_library_creativeattribute_slug_34d734e6_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_creativeattribute_slug_34d734e6_like ON public.content_library_creativeattribute USING btree (slug varchar_pattern_ops);


--
-- Name: content_library_creativeattribute_updated_by_id_3487042e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_creativeattribute_updated_by_id_3487042e ON public.content_library_creativeattribute USING btree (updated_by_id);


--
-- Name: content_library_creativeattributechoice_attribute_id_bc12d687; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_creativeattributechoice_attribute_id_bc12d687 ON public.content_library_creativeattributechoice USING btree (attribute_id);


--
-- Name: content_library_creativeco_content_block_id_4c672649; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_creativeco_content_block_id_4c672649 ON public.content_library_creativecontentblockdocument USING btree (content_block_id);


--
-- Name: content_library_creativeco_created_by_id_5f1dbd8d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_creativeco_created_by_id_5f1dbd8d ON public.content_library_creativecontentblockdocument USING btree (created_by_id);


--
-- Name: content_library_creativeco_creative_id_a1803c6d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_creativeco_creative_id_a1803c6d ON public.content_library_creativecontentblockdocument USING btree (creative_id);


--
-- Name: content_library_creativeco_updated_by_id_7df50456; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_creativeco_updated_by_id_7df50456 ON public.content_library_creativecontentblockdocument USING btree (updated_by_id);


--
-- Name: content_library_creativepromotion_creative_id_caf1233b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_creativepromotion_creative_id_caf1233b ON public.content_library_creativepromotion USING btree (creative_id);


--
-- Name: content_library_creativepromotion_promotion_id_eb18d4cb; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_creativepromotion_promotion_id_eb18d4cb ON public.content_library_creativepromotion USING btree (promotion_id);


--
-- Name: content_library_creativereuserule_created_by_id_3a52faef; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_creativereuserule_created_by_id_3a52faef ON public.content_library_creativereuserule USING btree (created_by_id);


--
-- Name: content_library_creativereuserule_updated_by_id_55192ec8; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_creativereuserule_updated_by_id_55192ec8 ON public.content_library_creativereuserule USING btree (updated_by_id);


--
-- Name: content_library_discountoffer_created_by_id_8f243674; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_discountoffer_created_by_id_8f243674 ON public.content_library_discountoffer USING btree (created_by_id);


--
-- Name: content_library_discountoffer_updated_by_id_6540cf87; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_discountoffer_updated_by_id_6540cf87 ON public.content_library_discountoffer USING btree (updated_by_id);


--
-- Name: content_library_document_content_block_id_7b98ba6e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_document_content_block_id_7b98ba6e ON public.content_library_document USING btree (content_block_id);


--
-- Name: content_library_document_created_by_id_62ad484d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_document_created_by_id_62ad484d ON public.content_library_document USING btree (created_by_id);


--
-- Name: content_library_document_creative_id_b40b302f; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_document_creative_id_b40b302f ON public.content_library_document USING btree (creative_id);


--
-- Name: content_library_document_promotion_redemption_id_48c744eb; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_document_promotion_redemption_id_48c744eb ON public.content_library_document USING btree (promotion_redemption_id);


--
-- Name: content_library_document_updated_by_id_2d8ba6e8; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_document_updated_by_id_2d8ba6e8 ON public.content_library_document USING btree (updated_by_id);


--
-- Name: content_library_dynamicsec_creatives_variant_id_65abb264; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_dynamicsec_creatives_variant_id_65abb264 ON public.content_library_dynamicsectionvariant USING btree (creatives_variant_id);


--
-- Name: content_library_dynamicsec_event_audience_id_192b13f0; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_dynamicsec_event_audience_id_192b13f0 ON public.content_library_dynamicsectionvariant USING btree (event_audience_id);


--
-- Name: content_library_dynamicsectionvariant_section_id_b91ebbfb; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_dynamicsectionvariant_section_id_b91ebbfb ON public.content_library_dynamicsectionvariant USING btree (section_id);


--
-- Name: content_library_eligiblecr_eligiblecreativestreatment_b3c1ec1f; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eligiblecr_eligiblecreativestreatment_b3c1ec1f ON public.content_library_eligiblecreativesvariant_treatments USING btree (eligiblecreativestreatment_id);


--
-- Name: content_library_eligiblecr_eligiblecreativesvariant_i_002d87a1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eligiblecr_eligiblecreativesvariant_i_002d87a1 ON public.content_library_eligiblecreativesvariant_treatments USING btree (eligiblecreativesvariant_id);


--
-- Name: content_library_eligiblecr_experiment_id_d3753aeb; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eligiblecr_experiment_id_d3753aeb ON public.content_library_eligiblecreativestreatment USING btree (experiment_id);


--
-- Name: content_library_eligiblecreativesvariant_event_id_fa443f0b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eligiblecreativesvariant_event_id_fa443f0b ON public.content_library_eligiblecreativesvariant USING btree (event_id);


--
-- Name: content_library_emailserviceprovider_cp_client_id_bb623a30; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_emailserviceprovider_cp_client_id_bb623a30 ON public.content_library_emailserviceprovider USING btree (cp_client_id);


--
-- Name: content_library_event_base_template_id_9fdd99fb; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_event_base_template_id_9fdd99fb ON public.content_library_event USING btree (base_template_id);


--
-- Name: content_library_event_client_id_cadc2dc3; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_event_client_id_cadc2dc3 ON public.content_library_event USING btree (client_id);


--
-- Name: content_library_event_created_by_id_8e4b7c64; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_event_created_by_id_8e4b7c64 ON public.content_library_event USING btree (created_by_id);


--
-- Name: content_library_event_persado_campaign_id_3ad69923; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_event_persado_campaign_id_3ad69923 ON public.content_library_event USING btree (persado_campaign_id);


--
-- Name: content_library_event_send_date_7b051a02; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_event_send_date_7b051a02 ON public.content_library_event USING btree (send_date);


--
-- Name: content_library_event_send_datetime_3d76373d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_event_send_datetime_3d76373d ON public.content_library_event USING btree (send_datetime);


--
-- Name: content_library_event_short_uuid_09966b9d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_event_short_uuid_09966b9d ON public.content_library_event USING btree (short_uuid);


--
-- Name: content_library_event_short_uuid_09966b9d_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_event_short_uuid_09966b9d_like ON public.content_library_event USING btree (short_uuid varchar_pattern_ops);


--
-- Name: content_library_event_slug_c37b5f92; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_event_slug_c37b5f92 ON public.content_library_event USING btree (slug);


--
-- Name: content_library_event_slug_c37b5f92_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_event_slug_c37b5f92_like ON public.content_library_event USING btree (slug varchar_pattern_ops);


--
-- Name: content_library_event_status_05803f98; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_event_status_05803f98 ON public.content_library_event USING btree (status);


--
-- Name: content_library_event_status_05803f98_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_event_status_05803f98_like ON public.content_library_event USING btree (status varchar_pattern_ops);


--
-- Name: content_library_event_tags_event_id_bdc79282; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_event_tags_event_id_bdc79282 ON public.content_library_event_tags USING btree (event_id);


--
-- Name: content_library_event_tags_tag_id_9af64c32; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_event_tags_tag_id_9af64c32 ON public.content_library_event_tags USING btree (tag_id);


--
-- Name: content_library_event_template_id_ffcf881b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_event_template_id_ffcf881b ON public.content_library_event USING btree (template_id);


--
-- Name: content_library_event_title_0f7093d0; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_event_title_0f7093d0 ON public.content_library_event USING btree (title);


--
-- Name: content_library_event_title_0f7093d0_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_event_title_0f7093d0_like ON public.content_library_event USING btree (title varchar_pattern_ops);


--
-- Name: content_library_event_updated_by_id_86dfa1b7; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_event_updated_by_id_86dfa1b7 ON public.content_library_event USING btree (updated_by_id);


--
-- Name: content_library_eventacous_created_by_id_425c3b45; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventacous_created_by_id_425c3b45 ON public.content_library_eventacousticcampaignconfig USING btree (created_by_id);


--
-- Name: content_library_eventacous_from_address_id_99dbef13; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventacous_from_address_id_99dbef13 ON public.content_library_eventacousticcampaignconfig USING btree (from_address_id);


--
-- Name: content_library_eventacous_from_name_id_39635b74; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventacous_from_name_id_39635b74 ON public.content_library_eventacousticcampaignconfig USING btree (from_name_id);


--
-- Name: content_library_eventacous_reply_to_id_e6bd9ab7; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventacous_reply_to_id_e6bd9ab7 ON public.content_library_eventacousticcampaignconfig USING btree (reply_to_id);


--
-- Name: content_library_eventacous_updated_by_id_86c5340f; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventacous_updated_by_id_86c5340f ON public.content_library_eventacousticcampaignconfig USING btree (updated_by_id);


--
-- Name: content_library_eventattri_created_by_id_53d56566; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventattri_created_by_id_53d56566 ON public.content_library_eventattributechoicecheetahdigitalselectionid USING btree (created_by_id);


--
-- Name: content_library_eventattri_created_by_id_ba0b8118; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventattri_created_by_id_ba0b8118 ON public.content_library_eventattributecheetahdigitaloptionid USING btree (created_by_id);


--
-- Name: content_library_eventattri_created_by_id_fc6f1668; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventattri_created_by_id_fc6f1668 ON public.content_library_eventattributeoracleresponsyscampaignvariable USING btree (created_by_id);


--
-- Name: content_library_eventattri_updated_by_id_53af34b8; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventattri_updated_by_id_53af34b8 ON public.content_library_eventattributechoicecheetahdigitalselectionid USING btree (updated_by_id);


--
-- Name: content_library_eventattri_updated_by_id_8b8a51b5; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventattri_updated_by_id_8b8a51b5 ON public.content_library_eventattributecheetahdigitaloptionid USING btree (updated_by_id);


--
-- Name: content_library_eventattri_updated_by_id_cc52a2c4; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventattri_updated_by_id_cc52a2c4 ON public.content_library_eventattributeoracleresponsyscampaignvariable USING btree (updated_by_id);


--
-- Name: content_library_eventattribute_client_id_36b827ec; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventattribute_client_id_36b827ec ON public.content_library_eventattribute USING btree (client_id);


--
-- Name: content_library_eventattribute_created_by_id_e14de076; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventattribute_created_by_id_e14de076 ON public.content_library_eventattribute USING btree (created_by_id);


--
-- Name: content_library_eventattribute_slug_3eb8823a; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventattribute_slug_3eb8823a ON public.content_library_eventattribute USING btree (slug);


--
-- Name: content_library_eventattribute_slug_3eb8823a_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventattribute_slug_3eb8823a_like ON public.content_library_eventattribute USING btree (slug varchar_pattern_ops);


--
-- Name: content_library_eventattribute_updated_by_id_63f1aab6; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventattribute_updated_by_id_63f1aab6 ON public.content_library_eventattribute USING btree (updated_by_id);


--
-- Name: content_library_eventattributechoice_attribute_id_9704516b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventattributechoice_attribute_id_9704516b ON public.content_library_eventattributechoice USING btree (attribute_id);


--
-- Name: content_library_eventattributechoice_created_by_id_617d6d8a; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventattributechoice_created_by_id_617d6d8a ON public.content_library_eventattributechoice USING btree (created_by_id);


--
-- Name: content_library_eventattributechoice_updated_by_id_6d4b4245; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventattributechoice_updated_by_id_6d4b4245 ON public.content_library_eventattributechoice USING btree (updated_by_id);


--
-- Name: content_library_eventaudiencefilter_audience_filter_id_5af2e656; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventaudiencefilter_audience_filter_id_5af2e656 ON public.content_library_eventaudience USING btree (audience_id);


--
-- Name: content_library_eventaudiencefilter_event_id_de0691fd; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventaudiencefilter_event_id_de0691fd ON public.content_library_eventaudience USING btree (event_id);


--
-- Name: content_library_eventconte_content_block_id_56d61767; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventconte_content_block_id_56d61767 ON public.content_library_eventcontentblockcreativestats USING btree (content_block_id);


--
-- Name: content_library_eventconte_event_id_e84a944c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventconte_event_id_e84a944c ON public.content_library_eventcontentblockcreativestats USING btree (event_id);


--
-- Name: content_library_eventoracl_created_by_id_804ba9b8; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventoracl_created_by_id_804ba9b8 ON public.content_library_eventoracleresponsysconfig USING btree (created_by_id);


--
-- Name: content_library_eventoracl_eventoracleresponsysconfig_3dcab5f3; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventoracl_eventoracleresponsysconfig_3dcab5f3 ON public.content_library_eventoracleresponsysconfig_suppressions USING btree (eventoracleresponsysconfig_id);


--
-- Name: content_library_eventoracl_eventoracleresponsysconfig_b5eb2123; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventoracl_eventoracleresponsysconfig_b5eb2123 ON public.content_library_eventoracleresponsysconfig_additional_data_13a0 USING btree (eventoracleresponsysconfig_id);


--
-- Name: content_library_eventoracl_marketing_program_id_e517290d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventoracl_marketing_program_id_e517290d ON public.content_library_eventoracleresponsysconfig USING btree (marketing_program_id);


--
-- Name: content_library_eventoracl_marketing_strategy_id_261a90aa; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventoracl_marketing_strategy_id_261a90aa ON public.content_library_eventoracleresponsysconfig USING btree (marketing_strategy_id);


--
-- Name: content_library_eventoracl_oracleresponsysadditionald_2e690b16; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventoracl_oracleresponsysadditionald_2e690b16 ON public.content_library_eventoracleresponsysconfig_additional_data_13a0 USING btree (oracleresponsysadditionaldatasource_id);


--
-- Name: content_library_eventoracl_oracleresponsyssuppression_9de47907; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventoracl_oracleresponsyssuppression_9de47907 ON public.content_library_eventoracleresponsysconfig_suppressions USING btree (oracleresponsyssuppression_id);


--
-- Name: content_library_eventoracl_sender_profile_id_bc6220aa; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventoracl_sender_profile_id_bc6220aa ON public.content_library_eventoracleresponsysconfig USING btree (sender_profile_id);


--
-- Name: content_library_eventoracl_updated_by_id_b85a4210; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventoracl_updated_by_id_b85a4210 ON public.content_library_eventoracleresponsysconfig USING btree (updated_by_id);


--
-- Name: content_library_eventrun_event_id_3cf4563a; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventrun_event_id_3cf4563a ON public.content_library_eventrun USING btree (event_id);


--
-- Name: content_library_eventsales_created_by_id_5ee445be; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventsales_created_by_id_5ee445be ON public.content_library_eventsalesforcemarketingcloudconfig USING btree (created_by_id);


--
-- Name: content_library_eventsales_eventsalesforcemarketingcl_21d5d7d2; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventsales_eventsalesforcemarketingcl_21d5d7d2 ON public.content_library_eventsalesforcemarketingcloudconfig_suppresa376 USING btree (eventsalesforcemarketingcloudconfig_id);


--
-- Name: content_library_eventsales_publication_list_id_8e9b5d43; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventsales_publication_list_id_8e9b5d43 ON public.content_library_eventsalesforcemarketingcloudconfig USING btree (publication_list_id);


--
-- Name: content_library_eventsales_salesforcemarketingcloudsu_bd343078; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventsales_salesforcemarketingcloudsu_bd343078 ON public.content_library_eventsalesforcemarketingcloudconfig_suppresa376 USING btree (salesforcemarketingcloudsuppressiondataextension_id);


--
-- Name: content_library_eventsales_sender_profile_id_22c81e12; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventsales_sender_profile_id_22c81e12 ON public.content_library_eventsalesforcemarketingcloudconfig USING btree (sender_profile_id);


--
-- Name: content_library_eventsales_updated_by_id_0cd09014; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventsales_updated_by_id_0cd09014 ON public.content_library_eventsalesforcemarketingcloudconfig USING btree (updated_by_id);


--
-- Name: content_library_eventstatus_event_id_babfc1cc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventstatus_event_id_babfc1cc ON public.content_library_eventstatus USING btree (event_id);


--
-- Name: content_library_eventstatus_user_id_d6cd515e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventstatus_user_id_d6cd515e ON public.content_library_eventstatus USING btree (user_id);


--
-- Name: content_library_eventtasklog_event_id_1ea917e1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventtasklog_event_id_1ea917e1 ON public.content_library_eventtasklog USING btree (event_id);


--
-- Name: content_library_eventtrackingpixel_event_id_16a1c12e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_eventtrackingpixel_event_id_16a1c12e ON public.content_library_eventtrackingpixel USING btree (event_id);


--
-- Name: content_library_footertemp_content_block_id_95269a27; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_footertemp_content_block_id_95269a27 ON public.content_library_footertemplatecontentblock USING btree (content_block_id);


--
-- Name: content_library_footertemp_footer_template_id_9f9390fb; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_footertemp_footer_template_id_9f9390fb ON public.content_library_footertemplatecontentblock USING btree (footer_template_id);


--
-- Name: content_library_footertemplate_base_template_id_c7e72ba6; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_footertemplate_base_template_id_c7e72ba6 ON public.content_library_footertemplate USING btree (base_template_id);


--
-- Name: content_library_footertemplate_body_id_660328de; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_footertemplate_body_id_660328de ON public.content_library_footertemplate USING btree (body_id);


--
-- Name: content_library_freegift_created_by_id_0221e46a; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_freegift_created_by_id_0221e46a ON public.content_library_freegift USING btree (created_by_id);


--
-- Name: content_library_freegift_updated_by_id_75011214; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_freegift_updated_by_id_75011214 ON public.content_library_freegift USING btree (updated_by_id);


--
-- Name: content_library_headertemp_content_block_id_dd77f560; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_headertemp_content_block_id_dd77f560 ON public.content_library_headertemplatecontentblock USING btree (content_block_id);


--
-- Name: content_library_headertemp_header_template_id_500a582a; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_headertemp_header_template_id_500a582a ON public.content_library_headertemplatecontentblock USING btree (header_template_id);


--
-- Name: content_library_headertemplate_base_template_id_35a1cd94; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_headertemplate_base_template_id_35a1cd94 ON public.content_library_headertemplate USING btree (base_template_id);


--
-- Name: content_library_headertemplate_body_id_ddedf73b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_headertemplate_body_id_ddedf73b ON public.content_library_headertemplate USING btree (body_id);


--
-- Name: content_library_htmlbundle_client_id_217e9e4c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_htmlbundle_client_id_217e9e4c ON public.content_library_htmlbundle USING btree (client_id);


--
-- Name: content_library_htmlbundle_created_by_id_6619470c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_htmlbundle_created_by_id_6619470c ON public.content_library_htmlbundle USING btree (created_by_id);


--
-- Name: content_library_htmlbundle_updated_by_id_1682cdf6; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_htmlbundle_updated_by_id_1682cdf6 ON public.content_library_htmlbundle USING btree (updated_by_id);


--
-- Name: content_library_htmlbundleimage_created_by_id_c0e4b8a3; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_htmlbundleimage_created_by_id_c0e4b8a3 ON public.content_library_htmlbundleimage USING btree (created_by_id);


--
-- Name: content_library_htmlbundleimage_html_bundle_id_c832f06a; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_htmlbundleimage_html_bundle_id_c832f06a ON public.content_library_htmlbundleimage USING btree (html_bundle_id);


--
-- Name: content_library_htmlbundleimage_updated_by_id_b11d9e63; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_htmlbundleimage_updated_by_id_b11d9e63 ON public.content_library_htmlbundleimage USING btree (updated_by_id);


--
-- Name: content_library_htmlbundlelink_html_bundle_id_1f853176; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_htmlbundlelink_html_bundle_id_1f853176 ON public.content_library_htmlbundlelink USING btree (html_bundle_id);


--
-- Name: content_library_htmlbundlelink_link_id_3e2ef908; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_htmlbundlelink_link_id_3e2ef908 ON public.content_library_htmlbundlelink USING btree (link_id);


--
-- Name: content_library_image_client_id_c3e417e2; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_image_client_id_c3e417e2 ON public.content_library_image USING btree (client_id);


--
-- Name: content_library_image_created_by_id_3076f234; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_image_created_by_id_3076f234 ON public.content_library_image USING btree (created_by_id);


--
-- Name: content_library_image_short_uuid_90062c0e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_image_short_uuid_90062c0e ON public.content_library_image USING btree (short_uuid);


--
-- Name: content_library_image_short_uuid_90062c0e_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_image_short_uuid_90062c0e_like ON public.content_library_image USING btree (short_uuid varchar_pattern_ops);


--
-- Name: content_library_image_updated_by_id_560e3bbe; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_image_updated_by_id_560e3bbe ON public.content_library_image USING btree (updated_by_id);


--
-- Name: content_library_imagelayout_client_id_dd0194f9; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_imagelayout_client_id_dd0194f9 ON public.content_library_imagelayout USING btree (client_id);


--
-- Name: content_library_imagelayout_created_by_id_1af5c17e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_imagelayout_created_by_id_1af5c17e ON public.content_library_imagelayout USING btree (created_by_id);


--
-- Name: content_library_imagelayout_updated_by_id_dbc9cc7d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_imagelayout_updated_by_id_dbc9cc7d ON public.content_library_imagelayout USING btree (updated_by_id);


--
-- Name: content_library_imageslice_client_id_76e96698; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_imageslice_client_id_76e96698 ON public.content_library_imageslice USING btree (client_id);


--
-- Name: content_library_imageslice_created_by_id_74a09375; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_imageslice_created_by_id_74a09375 ON public.content_library_imageslice USING btree (created_by_id);


--
-- Name: content_library_imageslice_image_layout_id_d5834bdc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_imageslice_image_layout_id_d5834bdc ON public.content_library_imageslice USING btree (image_layout_id);


--
-- Name: content_library_imageslice_updated_by_id_04b84d6b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_imageslice_updated_by_id_04b84d6b ON public.content_library_imageslice USING btree (updated_by_id);


--
-- Name: content_library_inboxprevi_subject_line_prefix_dynami_88f002db; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_inboxprevi_subject_line_prefix_dynami_88f002db ON public.content_library_inboxpreview USING btree (subject_line_prefix_dynamic_id);


--
-- Name: content_library_inboxprevi_subject_line_suffix_dynami_e69808f6; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_inboxprevi_subject_line_suffix_dynami_e69808f6 ON public.content_library_inboxpreview USING btree (subject_line_suffix_dynamic_id);


--
-- Name: content_library_inboxpreview_created_by_id_93940b03; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_inboxpreview_created_by_id_93940b03 ON public.content_library_inboxpreview USING btree (created_by_id);


--
-- Name: content_library_inboxpreview_creatives_variant_id_d5dc162f; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_inboxpreview_creatives_variant_id_d5dc162f ON public.content_library_inboxpreview USING btree (creatives_variant_id);


--
-- Name: content_library_inboxpreview_discount_offer_dynamic_id_4a48ca28; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_inboxpreview_discount_offer_dynamic_id_4a48ca28 ON public.content_library_inboxpreview USING btree (discount_offer_dynamic_id);


--
-- Name: content_library_inboxpreview_event_audience_id_5a78840b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_inboxpreview_event_audience_id_5a78840b ON public.content_library_inboxpreview USING btree (event_audience_id);


--
-- Name: content_library_inboxpreview_preheader_dynamic_id_ddd450ba; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_inboxpreview_preheader_dynamic_id_ddd450ba ON public.content_library_inboxpreview USING btree (preheader_dynamic_id);


--
-- Name: content_library_inboxpreview_preheader_link_static_id_9b7cfc92; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_inboxpreview_preheader_link_static_id_9b7cfc92 ON public.content_library_inboxpreview USING btree (preheader_link_static_id);


--
-- Name: content_library_inboxpreview_promotion_card_dynamic_id_c279904d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_inboxpreview_promotion_card_dynamic_id_c279904d ON public.content_library_inboxpreview USING btree (promotion_card_dynamic_id);


--
-- Name: content_library_inboxpreview_subject_line_dynamic_id_dc9982bb; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_inboxpreview_subject_line_dynamic_id_dc9982bb ON public.content_library_inboxpreview USING btree (subject_line_dynamic_id);


--
-- Name: content_library_inboxpreview_updated_by_id_201ff340; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_inboxpreview_updated_by_id_201ff340 ON public.content_library_inboxpreview USING btree (updated_by_id);


--
-- Name: content_library_invitation_client_id_c4bbbbc2; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_invitation_client_id_c4bbbbc2 ON public.content_library_invitation USING btree (client_id);


--
-- Name: content_library_invitation_inviter_id_fcf23131; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_invitation_inviter_id_fcf23131 ON public.content_library_invitation USING btree (inviter_id);


--
-- Name: content_library_invitation_key_dc06dbdf_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_invitation_key_dc06dbdf_like ON public.content_library_invitation USING btree (key varchar_pattern_ops);


--
-- Name: content_library_layout_client_id_7f5058fd; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_layout_client_id_7f5058fd ON public.content_library_layout USING btree (client_id);


--
-- Name: content_library_layout_created_by_id_09cdda77; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_layout_created_by_id_09cdda77 ON public.content_library_layout USING btree (created_by_id);


--
-- Name: content_library_layout_updated_by_id_999b7ea1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_layout_updated_by_id_999b7ea1 ON public.content_library_layout USING btree (updated_by_id);


--
-- Name: content_library_link_url_178e0c4b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_link_url_178e0c4b ON public.content_library_link USING btree (url);


--
-- Name: content_library_link_url_178e0c4b_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_link_url_178e0c4b_like ON public.content_library_link USING btree (url varchar_pattern_ops);


--
-- Name: content_library_linkcategory_client_id_36425da4; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_linkcategory_client_id_36425da4 ON public.content_library_linkcategory USING btree (client_id);


--
-- Name: content_library_linkgroup_client_id_4e3e533f; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_linkgroup_client_id_4e3e533f ON public.content_library_linkgroup USING btree (client_id);


--
-- Name: content_library_neweligiblecreative_configured_by_id_3de9b983; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_neweligiblecreative_configured_by_id_3de9b983 ON public.content_library_neweligiblecreative USING btree (configured_by_id);


--
-- Name: content_library_neweligiblecreative_creative_id_6ab6b295; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_neweligiblecreative_creative_id_6ab6b295 ON public.content_library_neweligiblecreative USING btree (creative_id);


--
-- Name: content_library_neweligiblecreative_section_variant_id_c9a16766; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_neweligiblecreative_section_variant_id_c9a16766 ON public.content_library_neweligiblecreative USING btree (section_variant_id);


--
-- Name: content_library_newlink_client_id_070189e4; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_newlink_client_id_070189e4 ON public.content_library_link USING btree (client_id);


--
-- Name: content_library_newlink_created_by_id_f1f1bb05; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_newlink_created_by_id_f1f1bb05 ON public.content_library_link USING btree (created_by_id);


--
-- Name: content_library_newlink_link_group_id_5f6077f4; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_newlink_link_group_id_5f6077f4 ON public.content_library_link USING btree (link_group_id);


--
-- Name: content_library_newlink_short_uuid_6870e745_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_newlink_short_uuid_6870e745_like ON public.content_library_link USING btree (short_uuid varchar_pattern_ops);


--
-- Name: content_library_newlink_updated_by_id_c271a717; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_newlink_updated_by_id_c271a717 ON public.content_library_link USING btree (updated_by_id);


--
-- Name: content_library_neworacler_created_by_id_d569b7e4; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_neworacler_created_by_id_d569b7e4 ON public.content_library_neworacleresponsysclientconfig USING btree (created_by_id);


--
-- Name: content_library_neworacler_profile_list_id_4b8cd1fa; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_neworacler_profile_list_id_4b8cd1fa ON public.content_library_neworacleresponsysclientconfig USING btree (profile_list_id);


--
-- Name: content_library_neworacler_updated_by_id_40932b71; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_neworacler_updated_by_id_40932b71 ON public.content_library_neworacleresponsysclientconfig USING btree (updated_by_id);


--
-- Name: content_library_newsenddat_send_time_personalization__799fc884; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_newsenddat_send_time_personalization__799fc884 ON public.content_library_senddatetime USING btree (send_time_personalization_variant_id);


--
-- Name: content_library_offer_client_id_5aa6684c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_offer_client_id_5aa6684c ON public.content_library_offer USING btree (client_id);


--
-- Name: content_library_offer_content_type_id_c1e76fc5; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_offer_content_type_id_c1e76fc5 ON public.content_library_offer USING btree (content_type_id);


--
-- Name: content_library_offer_created_by_id_6a898c00; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_offer_created_by_id_6a898c00 ON public.content_library_offer USING btree (created_by_id);


--
-- Name: content_library_offer_updated_by_id_02884484; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_offer_updated_by_id_02884484 ON public.content_library_offer USING btree (updated_by_id);


--
-- Name: content_library_oracleresp_campaign_variable_id_0fbf4cbf; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_campaign_variable_id_0fbf4cbf ON public.content_library_oracleresponsyscampaignvariablechoice USING btree (campaign_variable_id);


--
-- Name: content_library_oracleresp_category_id_f290dc64; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_category_id_f290dc64 ON public.content_library_oracleresponsyslinkmetadata USING btree (category_id);


--
-- Name: content_library_oracleresp_client_id_05446fec; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_client_id_05446fec ON public.content_library_oracleresponsysmarketingprogram USING btree (client_id);


--
-- Name: content_library_oracleresp_client_id_0c70d09d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_client_id_0c70d09d ON public.content_library_oracleresponsysadditionaldatasource USING btree (client_id);


--
-- Name: content_library_oracleresp_client_id_aa4fcf37; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_client_id_aa4fcf37 ON public.content_library_oracleresponsysmarketingstrategy USING btree (client_id);


--
-- Name: content_library_oracleresp_client_id_d260876d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_client_id_d260876d ON public.content_library_oracleresponsyscampaignvariable USING btree (client_id);


--
-- Name: content_library_oracleresp_content_block_id_2c2fe159; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_content_block_id_2c2fe159 ON public.content_library_oracleresponsysstaticcontentblockdocument USING btree (content_block_id);


--
-- Name: content_library_oracleresp_content_block_id_60ef1de3; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_content_block_id_60ef1de3 ON public.content_library_oracleresponsyscreativecontentblockdocument USING btree (content_block_id);


--
-- Name: content_library_oracleresp_contentblock_id_af01d293; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_contentblock_id_af01d293 ON public.content_library_oracleresponsyscreativedocument USING btree (contentblock_id);


--
-- Name: content_library_oracleresp_created_by_id_05679091; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_created_by_id_05679091 ON public.content_library_oracleresponsysadditionaldatasource USING btree (created_by_id);


--
-- Name: content_library_oracleresp_created_by_id_3627512e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_created_by_id_3627512e ON public.content_library_oracleresponsyscreativecontentblockdocument USING btree (created_by_id);


--
-- Name: content_library_oracleresp_created_by_id_3d32e582; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_created_by_id_3d32e582 ON public.content_library_oracleresponsyslaunch USING btree (created_by_id);


--
-- Name: content_library_oracleresp_created_by_id_4964b3ec; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_created_by_id_4964b3ec ON public.content_library_oracleresponsyscreativedocument USING btree (created_by_id);


--
-- Name: content_library_oracleresp_created_by_id_67fb5b70; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_created_by_id_67fb5b70 ON public.content_library_oracleresponsyssenderprofile USING btree (created_by_id);


--
-- Name: content_library_oracleresp_created_by_id_758bf0ae; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_created_by_id_758bf0ae ON public.content_library_oracleresponsysclientconfig USING btree (created_by_id);


--
-- Name: content_library_oracleresp_created_by_id_7821702c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_created_by_id_7821702c ON public.content_library_oracleresponsysstaticcontentblockdocument USING btree (created_by_id);


--
-- Name: content_library_oracleresp_created_by_id_9d280e1b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_created_by_id_9d280e1b ON public.content_library_oracleresponsyscampaignvariable USING btree (created_by_id);


--
-- Name: content_library_oracleresp_created_by_id_a1a4183c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_created_by_id_a1a4183c ON public.content_library_oracleresponsyssuppression USING btree (created_by_id);


--
-- Name: content_library_oracleresp_created_by_id_c14df83d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_created_by_id_c14df83d ON public.content_library_oracleresponsyscreativediscountofferdocument USING btree (created_by_id);


--
-- Name: content_library_oracleresp_created_by_id_cf7ae778; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_created_by_id_cf7ae778 ON public.content_library_oracleresponsysmarketingprogram USING btree (created_by_id);


--
-- Name: content_library_oracleresp_created_by_id_e0705f0f; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_created_by_id_e0705f0f ON public.content_library_oracleresponsysmarketingstrategy USING btree (created_by_id);


--
-- Name: content_library_oracleresp_creative_id_6ee02c3f; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_creative_id_6ee02c3f ON public.content_library_oracleresponsyscreativecontentblockdocument USING btree (creative_id);


--
-- Name: content_library_oracleresp_creative_id_e518e9d3; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_creative_id_e518e9d3 ON public.content_library_oracleresponsyscreativedocument USING btree (creative_id);


--
-- Name: content_library_oracleresp_document_id_24fa9db8; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_document_id_24fa9db8 ON public.content_library_oracleresponsyscreativediscountofferdocument USING btree (document_id);


--
-- Name: content_library_oracleresp_oracle_responsys_id_12b58bba; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_oracle_responsys_id_12b58bba ON public.content_library_oracleresponsyslinkmetadata USING btree (oracle_responsys_id);


--
-- Name: content_library_oracleresp_promotion_redemption_id_126ead3d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_promotion_redemption_id_126ead3d ON public.content_library_oracleresponsyscreativediscountofferdocument USING btree (promotion_redemption_id);


--
-- Name: content_library_oracleresp_updated_by_id_1db86838; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_updated_by_id_1db86838 ON public.content_library_oracleresponsysmarketingstrategy USING btree (updated_by_id);


--
-- Name: content_library_oracleresp_updated_by_id_5b7a0dc1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_updated_by_id_5b7a0dc1 ON public.content_library_oracleresponsysclientconfig USING btree (updated_by_id);


--
-- Name: content_library_oracleresp_updated_by_id_5bee9e44; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_updated_by_id_5bee9e44 ON public.content_library_oracleresponsyscreativedocument USING btree (updated_by_id);


--
-- Name: content_library_oracleresp_updated_by_id_75de24b1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_updated_by_id_75de24b1 ON public.content_library_oracleresponsyssenderprofile USING btree (updated_by_id);


--
-- Name: content_library_oracleresp_updated_by_id_88e72c38; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_updated_by_id_88e72c38 ON public.content_library_oracleresponsyssuppression USING btree (updated_by_id);


--
-- Name: content_library_oracleresp_updated_by_id_8e9bbe5b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_updated_by_id_8e9bbe5b ON public.content_library_oracleresponsyslaunch USING btree (updated_by_id);


--
-- Name: content_library_oracleresp_updated_by_id_aca0610c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_updated_by_id_aca0610c ON public.content_library_oracleresponsyscreativecontentblockdocument USING btree (updated_by_id);


--
-- Name: content_library_oracleresp_updated_by_id_ad0c77e5; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_updated_by_id_ad0c77e5 ON public.content_library_oracleresponsyscreativediscountofferdocument USING btree (updated_by_id);


--
-- Name: content_library_oracleresp_updated_by_id_d56fade4; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_updated_by_id_d56fade4 ON public.content_library_oracleresponsyscampaignvariable USING btree (updated_by_id);


--
-- Name: content_library_oracleresp_updated_by_id_d74dcfe2; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_updated_by_id_d74dcfe2 ON public.content_library_oracleresponsysadditionaldatasource USING btree (updated_by_id);


--
-- Name: content_library_oracleresp_updated_by_id_f4783b47; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_updated_by_id_f4783b47 ON public.content_library_oracleresponsysmarketingprogram USING btree (updated_by_id);


--
-- Name: content_library_oracleresp_updated_by_id_f9fa3eb6; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresp_updated_by_id_f9fa3eb6 ON public.content_library_oracleresponsysstaticcontentblockdocument USING btree (updated_by_id);


--
-- Name: content_library_oracleresponsyseventmetadata_event_id_b6393c48; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresponsyseventmetadata_event_id_b6393c48 ON public.content_library_oracleresponsyslaunch USING btree (event_id);


--
-- Name: content_library_oracleresponsyslist_client_id_054d564c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresponsyslist_client_id_054d564c ON public.content_library_oracleresponsyslist USING btree (client_id);


--
-- Name: content_library_oracleresponsyslist_created_by_id_7140d345; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresponsyslist_created_by_id_7140d345 ON public.content_library_oracleresponsyslist USING btree (created_by_id);


--
-- Name: content_library_oracleresponsyslist_updated_by_id_447cbc5b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresponsyslist_updated_by_id_447cbc5b ON public.content_library_oracleresponsyslist USING btree (updated_by_id);


--
-- Name: content_library_oracleresponsyssenderprofile_client_id_36ef0422; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresponsyssenderprofile_client_id_36ef0422 ON public.content_library_oracleresponsyssenderprofile USING btree (client_id);


--
-- Name: content_library_oracleresponsyssuppression_client_id_f6b005e4; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_oracleresponsyssuppression_client_id_f6b005e4 ON public.content_library_oracleresponsyssuppression USING btree (client_id);


--
-- Name: content_library_persadocampaign_campaign_id_4b921c0f; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_persadocampaign_campaign_id_4b921c0f ON public.content_library_persadocampaign USING btree (campaign_id);


--
-- Name: content_library_persadocampaign_client_id_32776b97; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_persadocampaign_client_id_32776b97 ON public.content_library_persadocampaign USING btree (client_id);


--
-- Name: content_library_persadocampaign_created_by_id_1283c4f0; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_persadocampaign_created_by_id_1283c4f0 ON public.content_library_persadocampaign USING btree (created_by_id);


--
-- Name: content_library_persadocampaign_updated_by_id_613be960; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_persadocampaign_updated_by_id_613be960 ON public.content_library_persadocampaign USING btree (updated_by_id);


--
-- Name: content_library_predefinedlayoutstructure_title_6a37cc8e_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_predefinedlayoutstructure_title_6a37cc8e_like ON public.content_library_predefinedlayoutstructure USING btree (title varchar_pattern_ops);


--
-- Name: content_library_productcol_productcollection_id_4720bba8; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_productcol_productcollection_id_4720bba8 ON public.content_library_productcollection_product_values USING btree (productcollection_id);


--
-- Name: content_library_productcol_productvalue_id_7427607c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_productcol_productvalue_id_7427607c ON public.content_library_productcollection_product_values USING btree (productvalue_id);


--
-- Name: content_library_productcollection_created_by_id_2c4c4cda; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_productcollection_created_by_id_2c4c4cda ON public.content_library_productcollection USING btree (created_by_id);


--
-- Name: content_library_productcollection_updated_by_id_85682f17; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_productcollection_updated_by_id_85682f17 ON public.content_library_productcollection USING btree (updated_by_id);


--
-- Name: content_library_productfield_client_id_d92969e7; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_productfield_client_id_d92969e7 ON public.content_library_productfield USING btree (client_id);


--
-- Name: content_library_productfield_created_by_id_4fdc2892; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_productfield_created_by_id_4fdc2892 ON public.content_library_productfield USING btree (created_by_id);


--
-- Name: content_library_productfield_updated_by_id_3308a3d4; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_productfield_updated_by_id_3308a3d4 ON public.content_library_productfield USING btree (updated_by_id);


--
-- Name: content_library_productvalue_created_by_id_205d365e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_productvalue_created_by_id_205d365e ON public.content_library_productvalue USING btree (created_by_id);


--
-- Name: content_library_productvalue_product_field_id_683581fe; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_productvalue_product_field_id_683581fe ON public.content_library_productvalue USING btree (product_field_id);


--
-- Name: content_library_productvalue_updated_by_id_9d96e51c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_productvalue_updated_by_id_9d96e51c ON public.content_library_productvalue USING btree (updated_by_id);


--
-- Name: content_library_prohibited_created_by_id_370dc116; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_prohibited_created_by_id_370dc116 ON public.content_library_prohibitedcreativeproductcollection USING btree (created_by_id);


--
-- Name: content_library_prohibited_creative_id_9ca7812b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_prohibited_creative_id_9ca7812b ON public.content_library_prohibitedcreativeproductcollection USING btree (creative_id);


--
-- Name: content_library_prohibited_productcollection_id_1ce02a0c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_prohibited_productcollection_id_1ce02a0c ON public.content_library_prohibitedcreativeproductcollection USING btree (productcollection_id);


--
-- Name: content_library_prohibited_updated_by_id_b38c8a67; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_prohibited_updated_by_id_b38c8a67 ON public.content_library_prohibitedcreativeproductcollection USING btree (updated_by_id);


--
-- Name: content_library_prohibitedcreativetag_created_by_id_d23cc545; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_prohibitedcreativetag_created_by_id_d23cc545 ON public.content_library_prohibitedcreativetag USING btree (created_by_id);


--
-- Name: content_library_prohibitedcreativetag_creative_id_5e30bba8; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_prohibitedcreativetag_creative_id_5e30bba8 ON public.content_library_prohibitedcreativetag USING btree (creative_id);


--
-- Name: content_library_prohibitedcreativetag_tag_id_73c6d633; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_prohibitedcreativetag_tag_id_73c6d633 ON public.content_library_prohibitedcreativetag USING btree (tag_id);


--
-- Name: content_library_prohibitedcreativetag_updated_by_id_99e690dc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_prohibitedcreativetag_updated_by_id_99e690dc ON public.content_library_prohibitedcreativetag USING btree (updated_by_id);


--
-- Name: content_library_promotion_client_id_236e610b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_promotion_client_id_236e610b ON public.content_library_promotion USING btree (client_id);


--
-- Name: content_library_promotion_created_by_id_2e45378c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_promotion_created_by_id_2e45378c ON public.content_library_promotion USING btree (created_by_id);


--
-- Name: content_library_promotion_description_34513381; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_promotion_description_34513381 ON public.content_library_promotion USING btree (description);


--
-- Name: content_library_promotion_description_34513381_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_promotion_description_34513381_like ON public.content_library_promotion USING btree (description varchar_pattern_ops);


--
-- Name: content_library_promotion_serialized_8794998d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_promotion_serialized_8794998d ON public.content_library_promotion USING btree (serialized);


--
-- Name: content_library_promotion_title_101873b7; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_promotion_title_101873b7 ON public.content_library_promotion USING btree (title);


--
-- Name: content_library_promotion_title_101873b7_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_promotion_title_101873b7_like ON public.content_library_promotion USING btree (title varchar_pattern_ops);


--
-- Name: content_library_promotion_updated_by_id_caea0134; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_promotion_updated_by_id_caea0134 ON public.content_library_promotion USING btree (updated_by_id);


--
-- Name: content_library_promotionoffer_offer_id_3219499f; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_promotionoffer_offer_id_3219499f ON public.content_library_promotionoffer USING btree (offer_id);


--
-- Name: content_library_promotionoffer_promotion_id_87815beb; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_promotionoffer_promotion_id_87815beb ON public.content_library_promotionoffer USING btree (promotion_id);


--
-- Name: content_library_promotionredemption_promotion_id_5781df86; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_promotionredemption_promotion_id_5781df86 ON public.content_library_promotionredemption USING btree (promotion_id);


--
-- Name: content_library_proxycontroltreatment_experiment_id_0e6ec5ee; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_proxycontroltreatment_experiment_id_0e6ec5ee ON public.content_library_proxycontroltreatment USING btree (experiment_id);


--
-- Name: content_library_proxycontrolvariant_created_by_id_3d265952; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_proxycontrolvariant_created_by_id_3d265952 ON public.content_library_proxycontrolvariant USING btree (created_by_id);


--
-- Name: content_library_proxycontrolvariant_event_id_8c855aa0; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_proxycontrolvariant_event_id_8c855aa0 ON public.content_library_proxycontrolvariant USING btree (event_id);


--
-- Name: content_library_proxycontrolvariant_treatment_id_95d14b42; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_proxycontrolvariant_treatment_id_95d14b42 ON public.content_library_proxycontrolvariant USING btree (treatment_id);


--
-- Name: content_library_proxycontrolvariant_updated_by_id_b46b8b90; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_proxycontrolvariant_updated_by_id_b46b8b90 ON public.content_library_proxycontrolvariant USING btree (updated_by_id);


--
-- Name: content_library_quantitydiscount_created_by_id_8a3ef5c0; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_quantitydiscount_created_by_id_8a3ef5c0 ON public.content_library_quantitydiscount USING btree (created_by_id);


--
-- Name: content_library_quantitydiscount_updated_by_id_e4d275fc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_quantitydiscount_updated_by_id_e4d275fc ON public.content_library_quantitydiscount USING btree (updated_by_id);


--
-- Name: content_library_querystringparameter_client_id_c36de163; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_querystringparameter_client_id_c36de163 ON public.content_library_querystringparameter USING btree (client_id);


--
-- Name: content_library_querystringparameter_created_by_id_cb89cf61; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_querystringparameter_created_by_id_cb89cf61 ON public.content_library_querystringparameter USING btree (created_by_id);


--
-- Name: content_library_querystringparameter_updated_by_id_8e362a06; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_querystringparameter_updated_by_id_8e362a06 ON public.content_library_querystringparameter USING btree (updated_by_id);


--
-- Name: content_library_recommenda_recommendation_run_id_eb3e0a47; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_recommenda_recommendation_run_id_eb3e0a47 ON public.content_library_recommendationrunlog USING btree (recommendation_run_id);


--
-- Name: content_library_recommenda_recommendationrun_id_57048bca; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_recommenda_recommendationrun_id_57048bca ON public.content_library_recommendationrun_events USING btree (recommendationrun_id);


--
-- Name: content_library_recommendationrun_client_id_d6a21a93; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_recommendationrun_client_id_d6a21a93 ON public.content_library_recommendationrun USING btree (client_id);


--
-- Name: content_library_recommendationrun_events_event_id_8ddefaf2; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_recommendationrun_events_event_id_8ddefaf2 ON public.content_library_recommendationrun_events USING btree (event_id);


--
-- Name: content_library_recommendationrunlog_event_id_c85a4be2; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_recommendationrunlog_event_id_c85a4be2 ON public.content_library_recommendationrunlog USING btree (event_id);


--
-- Name: content_library_recommendationsversion_created_by_id_711314d8; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_recommendationsversion_created_by_id_711314d8 ON public.content_library_contentpersonalizationmodel USING btree (created_by_id);


--
-- Name: content_library_recommendationsversion_updated_by_id_236b84d1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_recommendationsversion_updated_by_id_236b84d1 ON public.content_library_contentpersonalizationmodel USING btree (updated_by_id);


--
-- Name: content_library_renderedcreative_content_block_id_abd8b635; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_renderedcreative_content_block_id_abd8b635 ON public.content_library_renderedcreative USING btree (content_block_id);


--
-- Name: content_library_renderedcreative_creative_id_3afc0353; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_renderedcreative_creative_id_3afc0353 ON public.content_library_renderedcreative USING btree (creative_id);


--
-- Name: content_library_rewardsmultiplier_created_by_id_5fe69c8f; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_rewardsmultiplier_created_by_id_5fe69c8f ON public.content_library_rewardsmultiplier USING btree (created_by_id);


--
-- Name: content_library_rewardsmultiplier_updated_by_id_70a6a62d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_rewardsmultiplier_updated_by_id_70a6a62d ON public.content_library_rewardsmultiplier USING btree (updated_by_id);


--
-- Name: content_library_salesfor_ftp_username_1a1fac1b_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_salesfor_ftp_username_1a1fac1b_like ON public.content_library_salesforcemarketingcloud USING btree (ftp_username varchar_pattern_ops);


--
-- Name: content_library_salesfor_member_id_609e0dcd_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_salesfor_member_id_609e0dcd_like ON public.content_library_salesforcemarketingcloud USING btree (member_id varchar_pattern_ops);


--
-- Name: content_library_salesfor_notify_email_f1f409ca_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_salesfor_notify_email_f1f409ca_like ON public.content_library_salesforcemarketingcloud USING btree (notify_email varchar_pattern_ops);


--
-- Name: content_library_salesforce_client_id_0ba374c3; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_salesforce_client_id_0ba374c3 ON public.content_library_salesforcemarketingcloudintegration USING btree (client_id);


--
-- Name: content_library_salesforce_client_id_13f69239; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_salesforce_client_id_13f69239 ON public.content_library_salesforcemarketingcloudpublicationlist USING btree (client_id);


--
-- Name: content_library_salesforce_client_id_51d8d6a6; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_salesforce_client_id_51d8d6a6 ON public.content_library_salesforcemarketingcloudsenderprofile USING btree (client_id);


--
-- Name: content_library_salesforce_client_id_ae30eb16; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_salesforce_client_id_ae30eb16 ON public.content_library_salesforcemarketingcloudsuppressiondataexte91a1 USING btree (client_id);


--
-- Name: content_library_salesforce_content_block_id_32694796; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_salesforce_content_block_id_32694796 ON public.content_library_salesforcemarketingcloudstaticcontentblockda7ea USING btree (content_block_id);


--
-- Name: content_library_salesforce_content_block_id_74ab0131; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_salesforce_content_block_id_74ab0131 ON public.content_library_salesforcemarketingcloudcreativecontentblocaf9f USING btree (content_block_id);


--
-- Name: content_library_salesforce_contentblock_id_6ebb3562; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_salesforce_contentblock_id_6ebb3562 ON public.content_library_salesforcemarketingcloudcreativedocument USING btree (contentblock_id);


--
-- Name: content_library_salesforce_created_by_id_2503522b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_salesforce_created_by_id_2503522b ON public.content_library_salesforcemarketingcloudcreativediscountoff3b11 USING btree (created_by_id);


--
-- Name: content_library_salesforce_created_by_id_2c67b657; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_salesforce_created_by_id_2c67b657 ON public.content_library_salesforcemarketingcloudsend USING btree (created_by_id);


--
-- Name: content_library_salesforce_created_by_id_329755dd; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_salesforce_created_by_id_329755dd ON public.content_library_salesforcemarketingcloudstaticcontentblockda7ea USING btree (created_by_id);


--
-- Name: content_library_salesforce_created_by_id_3e07ab26; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_salesforce_created_by_id_3e07ab26 ON public.content_library_salesforcemarketingcloudcreativedocument USING btree (created_by_id);


--
-- Name: content_library_salesforce_created_by_id_d37f1787; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_salesforce_created_by_id_d37f1787 ON public.content_library_salesforcemarketingcloudcreativecontentblocaf9f USING btree (created_by_id);


--
-- Name: content_library_salesforce_creative_id_50105783; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_salesforce_creative_id_50105783 ON public.content_library_salesforcemarketingcloudcreativecontentblocaf9f USING btree (creative_id);


--
-- Name: content_library_salesforce_creative_id_6ea18603; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_salesforce_creative_id_6ea18603 ON public.content_library_salesforcemarketingcloudcreativedocument USING btree (creative_id);


--
-- Name: content_library_salesforce_document_id_066dab8e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_salesforce_document_id_066dab8e ON public.content_library_salesforcemarketingcloudcreativediscountoff3b11 USING btree (document_id);


--
-- Name: content_library_salesforce_event_id_40729ffe; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_salesforce_event_id_40729ffe ON public.content_library_salesforcemarketingcloudsend USING btree (event_id);


--
-- Name: content_library_salesforce_promotion_redemption_id_3394d714; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_salesforce_promotion_redemption_id_3394d714 ON public.content_library_salesforcemarketingcloudcreativediscountoff3b11 USING btree (promotion_redemption_id);


--
-- Name: content_library_salesforce_salesforce_marketing_cloud_c6bb8f58; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_salesforce_salesforce_marketing_cloud_c6bb8f58 ON public.content_library_salesforcemarketingcloudlinkmetadata USING btree (salesforce_marketing_cloud_id);


--
-- Name: content_library_salesforce_updated_by_id_65115418; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_salesforce_updated_by_id_65115418 ON public.content_library_salesforcemarketingcloudstaticcontentblockda7ea USING btree (updated_by_id);


--
-- Name: content_library_salesforce_updated_by_id_66a73543; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_salesforce_updated_by_id_66a73543 ON public.content_library_salesforcemarketingcloudsend USING btree (updated_by_id);


--
-- Name: content_library_salesforce_updated_by_id_6b71a726; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_salesforce_updated_by_id_6b71a726 ON public.content_library_salesforcemarketingcloudcreativecontentblocaf9f USING btree (updated_by_id);


--
-- Name: content_library_salesforce_updated_by_id_7a20f932; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_salesforce_updated_by_id_7a20f932 ON public.content_library_salesforcemarketingcloudcreativediscountoff3b11 USING btree (updated_by_id);


--
-- Name: content_library_salesforce_updated_by_id_fbdff8da; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_salesforce_updated_by_id_fbdff8da ON public.content_library_salesforcemarketingcloudcreativedocument USING btree (updated_by_id);


--
-- Name: content_library_salesforce_user_id_b2d6092b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_salesforce_user_id_b2d6092b ON public.content_library_salesforcemarketingcloudintegration USING btree (user_id);


--
-- Name: content_library_salesforcemarketingcloud_ftp_password_284cf02f; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_salesforcemarketingcloud_ftp_password_284cf02f ON public.content_library_salesforcemarketingcloud USING btree (ftp_password);


--
-- Name: content_library_salesforcemarketingcloud_ftp_username_1a1fac1b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_salesforcemarketingcloud_ftp_username_1a1fac1b ON public.content_library_salesforcemarketingcloud USING btree (ftp_username);


--
-- Name: content_library_salesforcemarketingcloud_member_id_609e0dcd; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_salesforcemarketingcloud_member_id_609e0dcd ON public.content_library_salesforcemarketingcloud USING btree (member_id);


--
-- Name: content_library_salesforcemarketingcloud_notify_email_f1f409ca; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_salesforcemarketingcloud_notify_email_f1f409ca ON public.content_library_salesforcemarketingcloud USING btree (notify_email);


--
-- Name: content_library_section_contentblock_id_8bf94c1c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_section_contentblock_id_8bf94c1c ON public.content_library_section USING btree (contentblock_id);


--
-- Name: content_library_section_event_id_2c528bae; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_section_event_id_2c528bae ON public.content_library_section USING btree (event_id);


--
-- Name: content_library_section_template_variant_id_0738c336; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_section_template_variant_id_0738c336 ON public.content_library_section USING btree (template_variant_id);


--
-- Name: content_library_senddatetimetreatment_experiment_id_6c862b85; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_senddatetimetreatment_experiment_id_6c862b85 ON public.content_library_senddatetimetreatment USING btree (experiment_id);


--
-- Name: content_library_sendtimepe_created_by_id_c22af839; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_sendtimepe_created_by_id_c22af839 ON public.content_library_sendtimepersonalizationvariant USING btree (created_by_id);


--
-- Name: content_library_sendtimepe_event_id_e47c5144; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_sendtimepe_event_id_e47c5144 ON public.content_library_sendtimepersonalizationvariant USING btree (event_id);


--
-- Name: content_library_sendtimepe_treatment_id_452ee0e0; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_sendtimepe_treatment_id_452ee0e0 ON public.content_library_sendtimepersonalizationvariant USING btree (treatment_id);


--
-- Name: content_library_sendtimepe_updated_by_id_a644ea58; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_sendtimepe_updated_by_id_a644ea58 ON public.content_library_sendtimepersonalizationvariant USING btree (updated_by_id);


--
-- Name: content_library_session_client_id_f98b5006; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_session_client_id_f98b5006 ON public.content_library_session USING btree (client_id);


--
-- Name: content_library_session_expire_date_20357d63; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_session_expire_date_20357d63 ON public.content_library_session USING btree (expire_date);


--
-- Name: content_library_session_session_key_3539a3ca_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_session_session_key_3539a3ca_like ON public.content_library_session USING btree (session_key varchar_pattern_ops);


--
-- Name: content_library_slice_client_id_f8a2f90b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_slice_client_id_f8a2f90b ON public.content_library_slice USING btree (client_id);


--
-- Name: content_library_slice_created_by_id_57eeeae4; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_slice_created_by_id_57eeeae4 ON public.content_library_slice USING btree (created_by_id);


--
-- Name: content_library_slice_layout_id_8fd5c6ce; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_slice_layout_id_8fd5c6ce ON public.content_library_slice USING btree (layout_id);


--
-- Name: content_library_slice_updated_by_id_297a1753; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_slice_updated_by_id_297a1753 ON public.content_library_slice USING btree (updated_by_id);


--
-- Name: content_library_staticaudiencemetadata_audience_id_bb71969f; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_staticaudiencemetadata_audience_id_bb71969f ON public.content_library_staticaudiencemetadata USING btree (audience_id);


--
-- Name: content_library_staticaudiencemetadata_created_by_id_fd9581a3; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_staticaudiencemetadata_created_by_id_fd9581a3 ON public.content_library_staticaudiencemetadata USING btree (created_by_id);


--
-- Name: content_library_staticaudiencemetadata_updated_by_id_9aa4d906; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_staticaudiencemetadata_updated_by_id_9aa4d906 ON public.content_library_staticaudiencemetadata USING btree (updated_by_id);


--
-- Name: content_library_subjectline_created_by_id_f2aa13c4; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_subjectline_created_by_id_f2aa13c4 ON public.content_library_subjectline USING btree (created_by_id);


--
-- Name: content_library_subjectline_creative_id_7d3ce58d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_subjectline_creative_id_7d3ce58d ON public.content_library_subjectline USING btree (creative_id);


--
-- Name: content_library_subjectline_short_uuid_828ebc1b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_subjectline_short_uuid_828ebc1b ON public.content_library_subjectline USING btree (short_uuid);


--
-- Name: content_library_subjectline_short_uuid_828ebc1b_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_subjectline_short_uuid_828ebc1b_like ON public.content_library_subjectline USING btree (short_uuid varchar_pattern_ops);


--
-- Name: content_library_subjectline_updated_by_id_169e518d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_subjectline_updated_by_id_169e518d ON public.content_library_subjectline USING btree (updated_by_id);


--
-- Name: content_library_tag_client_id_135476bd; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_tag_client_id_135476bd ON public.content_library_tag USING btree (client_id);


--
-- Name: content_library_tag_created_by_id_cb1f66a9; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_tag_created_by_id_cb1f66a9 ON public.content_library_tag USING btree (created_by_id);


--
-- Name: content_library_tag_updated_by_id_95cfac41; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_tag_updated_by_id_95cfac41 ON public.content_library_tag USING btree (updated_by_id);


--
-- Name: content_library_template_body_html_bundle_id_85959f8a; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_template_body_html_bundle_id_85959f8a ON public.content_library_template USING btree (body_id);


--
-- Name: content_library_template_client_id_3919775d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_template_client_id_3919775d ON public.content_library_template USING btree (client_id);


--
-- Name: content_library_template_created_by_id_18c1f511; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_template_created_by_id_18c1f511 ON public.content_library_template USING btree (created_by_id);


--
-- Name: content_library_template_updated_by_id_feb2421d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_template_updated_by_id_feb2421d ON public.content_library_template USING btree (updated_by_id);


--
-- Name: content_library_templatecontentblock_content_block_id_62fb840a; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_templatecontentblock_content_block_id_62fb840a ON public.content_library_templatecontentblock USING btree (content_block_id);


--
-- Name: content_library_templatecontentblock_template_id_c6525434; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_templatecontentblock_template_id_c6525434 ON public.content_library_templatecontentblock USING btree (template_id);


--
-- Name: content_library_templatetag_client_id_c65b3508; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_templatetag_client_id_c65b3508 ON public.content_library_templatetag USING btree (client_id);


--
-- Name: content_library_templatetag_created_by_id_95d13a7b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_templatetag_created_by_id_95d13a7b ON public.content_library_templatetag USING btree (created_by_id);


--
-- Name: content_library_templatetag_slug_68145255; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_templatetag_slug_68145255 ON public.content_library_templatetag USING btree (slug);


--
-- Name: content_library_templatetag_slug_68145255_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_templatetag_slug_68145255_like ON public.content_library_templatetag USING btree (slug varchar_pattern_ops);


--
-- Name: content_library_templatetag_updated_by_id_64c4bb36; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_templatetag_updated_by_id_64c4bb36 ON public.content_library_templatetag USING btree (updated_by_id);


--
-- Name: content_library_templatetagchoice_template_tag_id_360f66c1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_templatetagchoice_template_tag_id_360f66c1 ON public.content_library_templatetagchoice USING btree (template_tag_id);


--
-- Name: content_library_templatetreatment_experiment_id_6ea4a0dd; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_templatetreatment_experiment_id_6ea4a0dd ON public.content_library_templatetreatment USING btree (experiment_id);


--
-- Name: content_library_templatevariant_created_by_id_fc984f40; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_templatevariant_created_by_id_fc984f40 ON public.content_library_templatevariant USING btree (created_by_id);


--
-- Name: content_library_templatevariant_event_id_e25d3bf9; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_templatevariant_event_id_e25d3bf9 ON public.content_library_templatevariant USING btree (event_id);


--
-- Name: content_library_templatevariant_treatment_id_38c77b4a; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_templatevariant_treatment_id_38c77b4a ON public.content_library_templatevariant USING btree (treatment_id);


--
-- Name: content_library_templatevariant_updated_by_id_b0cc528f; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_templatevariant_updated_by_id_b0cc528f ON public.content_library_templatevariant USING btree (updated_by_id);


--
-- Name: content_library_trackingpa_tracking_parameter_id_fcfca784; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_trackingpa_tracking_parameter_id_fcfca784 ON public.content_library_trackingparameterchoice USING btree (tracking_parameter_id);


--
-- Name: content_library_trackingparameter_client_id_af41118d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_trackingparameter_client_id_af41118d ON public.content_library_trackingparameter USING btree (client_id);


--
-- Name: content_library_trackingparameter_created_by_id_f6d91616; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_trackingparameter_created_by_id_f6d91616 ON public.content_library_trackingparameter USING btree (created_by_id);


--
-- Name: content_library_trackingparameter_slug_5bf7adac; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_trackingparameter_slug_5bf7adac ON public.content_library_trackingparameter USING btree (slug);


--
-- Name: content_library_trackingparameter_slug_5bf7adac_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_trackingparameter_slug_5bf7adac_like ON public.content_library_trackingparameter USING btree (slug varchar_pattern_ops);


--
-- Name: content_library_trackingparameter_updated_by_id_0bfed277; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_trackingparameter_updated_by_id_0bfed277 ON public.content_library_trackingparameter USING btree (updated_by_id);


--
-- Name: content_library_user_email_7a48a9be_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_user_email_7a48a9be_like ON public.content_library_user USING btree (email varchar_pattern_ops);


--
-- Name: content_library_user_groups_group_id_60d2a399; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_user_groups_group_id_60d2a399 ON public.content_library_user_groups USING btree (group_id);


--
-- Name: content_library_user_groups_user_id_5baf34c3; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_user_groups_user_id_5baf34c3 ON public.content_library_user_groups USING btree (user_id);


--
-- Name: content_library_user_user_permissions_permission_id_93c7b786; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_user_user_permissions_permission_id_93c7b786 ON public.content_library_user_user_permissions USING btree (permission_id);


--
-- Name: content_library_user_user_permissions_user_id_6c771372; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_library_user_user_permissions_user_id_6c771372 ON public.content_library_user_user_permissions USING btree (user_id);


--
-- Name: django_admin_log_content_type_id_c4bce8eb; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX django_admin_log_content_type_id_c4bce8eb ON public.django_admin_log USING btree (content_type_id);


--
-- Name: django_admin_log_user_id_c564eba6; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX django_admin_log_user_id_c564eba6 ON public.django_admin_log USING btree (user_id);


--
-- Name: django_celery_beat_periodictask_clocked_id_47a69f82; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX django_celery_beat_periodictask_clocked_id_47a69f82 ON public.django_celery_beat_periodictask USING btree (clocked_id);


--
-- Name: django_celery_beat_periodictask_crontab_id_d3cba168; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX django_celery_beat_periodictask_crontab_id_d3cba168 ON public.django_celery_beat_periodictask USING btree (crontab_id);


--
-- Name: django_celery_beat_periodictask_interval_id_a8ca27da; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX django_celery_beat_periodictask_interval_id_a8ca27da ON public.django_celery_beat_periodictask USING btree (interval_id);


--
-- Name: django_celery_beat_periodictask_name_265a36b7_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX django_celery_beat_periodictask_name_265a36b7_like ON public.django_celery_beat_periodictask USING btree (name varchar_pattern_ops);


--
-- Name: django_celery_beat_periodictask_solar_id_a87ce72c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX django_celery_beat_periodictask_solar_id_a87ce72c ON public.django_celery_beat_periodictask USING btree (solar_id);


--
-- Name: django_session_expire_date_a5c62663; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX django_session_expire_date_a5c62663 ON public.django_session USING btree (expire_date);


--
-- Name: django_session_session_key_c0390e0f_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX django_session_session_key_c0390e0f_like ON public.django_session USING btree (session_key varchar_pattern_ops);


--
-- Name: django_site_domain_a2e37b91_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX django_site_domain_a2e37b91_like ON public.django_site USING btree (domain varchar_pattern_ops);


--
-- Name: oauth2_provider_accesstoken_application_id_b22886e1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oauth2_provider_accesstoken_application_id_b22886e1 ON public.oauth2_provider_accesstoken USING btree (application_id);


--
-- Name: oauth2_provider_accesstoken_token_8af090f8_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oauth2_provider_accesstoken_token_8af090f8_like ON public.oauth2_provider_accesstoken USING btree (token varchar_pattern_ops);


--
-- Name: oauth2_provider_accesstoken_user_id_6e4c9a65; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oauth2_provider_accesstoken_user_id_6e4c9a65 ON public.oauth2_provider_accesstoken USING btree (user_id);


--
-- Name: oauth2_provider_grant_application_id_81923564; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oauth2_provider_grant_application_id_81923564 ON public.oauth2_provider_grant USING btree (application_id);


--
-- Name: oauth2_provider_grant_code_49ab4ddf_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oauth2_provider_grant_code_49ab4ddf_like ON public.oauth2_provider_grant USING btree (code varchar_pattern_ops);


--
-- Name: oauth2_provider_grant_user_id_e8f62af8; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oauth2_provider_grant_user_id_e8f62af8 ON public.oauth2_provider_grant USING btree (user_id);


--
-- Name: oauth2_provider_refreshtoken_application_id_2d1c311b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oauth2_provider_refreshtoken_application_id_2d1c311b ON public.oauth2_provider_refreshtoken USING btree (application_id);


--
-- Name: oauth2_provider_refreshtoken_token_d090daa4_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oauth2_provider_refreshtoken_token_d090daa4_like ON public.oauth2_provider_refreshtoken USING btree (token varchar_pattern_ops);


--
-- Name: oauth2_provider_refreshtoken_user_id_da837fce; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oauth2_provider_refreshtoken_user_id_da837fce ON public.oauth2_provider_refreshtoken USING btree (user_id);


--
-- Name: organizations_organization_slug_e36fd8f9_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX organizations_organization_slug_e36fd8f9_like ON public.organizations_organization USING btree (slug varchar_pattern_ops);


--
-- Name: organizations_organizationuser_organization_id_5376c939; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX organizations_organizationuser_organization_id_5376c939 ON public.organizations_organizationuser USING btree (organization_id);


--
-- Name: organizations_organizationuser_user_id_6c888ebd; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX organizations_organizationuser_user_id_6c888ebd ON public.organizations_organizationuser USING btree (user_id);


--
-- Name: account_emailaddress account_emailaddress_user_id_2c513194_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_emailaddress
    ADD CONSTRAINT account_emailaddress_user_id_2c513194_fk_content_l FOREIGN KEY (user_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: account_emailconfirmation account_emailconfirm_email_address_id_5b7f8c58_fk_account_e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_emailconfirmation
    ADD CONSTRAINT account_emailconfirm_email_address_id_5b7f8c58_fk_account_e FOREIGN KEY (email_address_id) REFERENCES public.account_emailaddress(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_group_permissions auth_group_permissio_permission_id_84c5c92e_fk_auth_perm; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm FOREIGN KEY (permission_id) REFERENCES public.auth_permission(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_group_permissions auth_group_permissions_group_id_b120cbf9_fk_auth_group_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES public.auth_group(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_permission auth_permission_content_type_id_2f476e4b_fk_django_co; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_acousticcampaignlinkmetadata content_library_acou_acoustic_campaign_id_53f8a80c_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_acousticcampaignlinkmetadata
    ADD CONSTRAINT content_library_acou_acoustic_campaign_id_53f8a80c_fk_content_l FOREIGN KEY (acoustic_campaign_id) REFERENCES public.content_library_acousticcampaign(emailserviceprovider_ptr_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_acousticcampaignfromname content_library_acou_client_id_cd8a54e2_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_acousticcampaignfromname
    ADD CONSTRAINT content_library_acou_client_id_cd8a54e2_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_acousticcampaignfromaddress content_library_acou_client_id_d5e48ee0_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_acousticcampaignfromaddress
    ADD CONSTRAINT content_library_acou_client_id_d5e48ee0_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_acousticcampaignreplyto content_library_acou_client_id_d6f246d4_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_acousticcampaignreplyto
    ADD CONSTRAINT content_library_acou_client_id_d6f246d4_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_acousticcampaignfromaddress content_library_acou_created_by_id_10840009_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_acousticcampaignfromaddress
    ADD CONSTRAINT content_library_acou_created_by_id_10840009_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_acousticcampaigndynamiccontent content_library_acou_created_by_id_12437f85_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_acousticcampaigndynamiccontent
    ADD CONSTRAINT content_library_acou_created_by_id_12437f85_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_acousticcampaignmailing content_library_acou_created_by_id_23cc41cc_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_acousticcampaignmailing
    ADD CONSTRAINT content_library_acou_created_by_id_23cc41cc_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_acousticcampaignfromname content_library_acou_created_by_id_61a3eebe_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_acousticcampaignfromname
    ADD CONSTRAINT content_library_acou_created_by_id_61a3eebe_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_acousticcampaignreplyto content_library_acou_created_by_id_85fdec87_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_acousticcampaignreplyto
    ADD CONSTRAINT content_library_acou_created_by_id_85fdec87_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_acousticcampaign content_library_acou_emailserviceprovider_0c09768c_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_acousticcampaign
    ADD CONSTRAINT content_library_acou_emailserviceprovider_0c09768c_fk_content_l FOREIGN KEY (emailserviceprovider_ptr_id) REFERENCES public.content_library_emailserviceprovider(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_acousticcampaignmailing content_library_acou_event_id_73b2d0d2_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_acousticcampaignmailing
    ADD CONSTRAINT content_library_acou_event_id_73b2d0d2_fk_content_l FOREIGN KEY (event_id) REFERENCES public.content_library_event(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_acousticcampaignlinkmetadata content_library_acou_link_id_f49834db_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_acousticcampaignlinkmetadata
    ADD CONSTRAINT content_library_acou_link_id_f49834db_fk_content_l FOREIGN KEY (link_id) REFERENCES public.content_library_link(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_acousticcampaigndynamiccontent content_library_acou_section_id_2bf1459b_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_acousticcampaigndynamiccontent
    ADD CONSTRAINT content_library_acou_section_id_2bf1459b_fk_content_l FOREIGN KEY (section_id) REFERENCES public.content_library_section(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_acousticcampaignmailing content_library_acou_updated_by_id_33f7b787_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_acousticcampaignmailing
    ADD CONSTRAINT content_library_acou_updated_by_id_33f7b787_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_acousticcampaignfromaddress content_library_acou_updated_by_id_367c635e_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_acousticcampaignfromaddress
    ADD CONSTRAINT content_library_acou_updated_by_id_367c635e_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_acousticcampaignreplyto content_library_acou_updated_by_id_6d503bb0_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_acousticcampaignreplyto
    ADD CONSTRAINT content_library_acou_updated_by_id_6d503bb0_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_acousticcampaignfromname content_library_acou_updated_by_id_73e0caf1_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_acousticcampaignfromname
    ADD CONSTRAINT content_library_acou_updated_by_id_73e0caf1_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_acousticcampaigndynamiccontent content_library_acou_updated_by_id_c608ce1a_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_acousticcampaigndynamiccontent
    ADD CONSTRAINT content_library_acou_updated_by_id_c608ce1a_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_adhocvariant_treatments content_library_adho_adhoctreatment_id_066394b4_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_adhocvariant_treatments
    ADD CONSTRAINT content_library_adho_adhoctreatment_id_066394b4_fk_content_l FOREIGN KEY (adhoctreatment_id) REFERENCES public.content_library_adhoctreatment(basetreatment_ptr_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_adhocvariant_treatments content_library_adho_adhocvariant_id_85208f50_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_adhocvariant_treatments
    ADD CONSTRAINT content_library_adho_adhocvariant_id_85208f50_fk_content_l FOREIGN KEY (adhocvariant_id) REFERENCES public.content_library_adhocvariant(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_adhocexperiment content_library_adho_baseexperiment_ptr_i_e4d8499e_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_adhocexperiment
    ADD CONSTRAINT content_library_adho_baseexperiment_ptr_i_e4d8499e_fk_content_l FOREIGN KEY (baseexperiment_ptr_id) REFERENCES public.content_library_baseexperiment(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_adhoctreatment content_library_adho_basetreatment_ptr_id_ef7039fd_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_adhoctreatment
    ADD CONSTRAINT content_library_adho_basetreatment_ptr_id_ef7039fd_fk_content_l FOREIGN KEY (basetreatment_ptr_id) REFERENCES public.content_library_basetreatment(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_adhocvariant content_library_adho_created_by_id_71cb08db_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_adhocvariant
    ADD CONSTRAINT content_library_adho_created_by_id_71cb08db_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_adhocvariant content_library_adho_event_id_3461cff0_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_adhocvariant
    ADD CONSTRAINT content_library_adho_event_id_3461cff0_fk_content_l FOREIGN KEY (event_id) REFERENCES public.content_library_event(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_adhoctreatment content_library_adho_experiment_id_a6d26b0b_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_adhoctreatment
    ADD CONSTRAINT content_library_adho_experiment_id_a6d26b0b_fk_content_l FOREIGN KEY (experiment_id) REFERENCES public.content_library_adhocexperiment(baseexperiment_ptr_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_adhocvariant content_library_adho_updated_by_id_60287550_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_adhocvariant
    ADD CONSTRAINT content_library_adho_updated_by_id_60287550_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_adobecampaigneventmetadata content_library_adob_created_by_id_007bd27e_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_adobecampaigneventmetadata
    ADD CONSTRAINT content_library_adob_created_by_id_007bd27e_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_adobecampaigneventmetadata content_library_adob_event_id_0f48fa59_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_adobecampaigneventmetadata
    ADD CONSTRAINT content_library_adob_event_id_0f48fa59_fk_content_l FOREIGN KEY (event_id) REFERENCES public.content_library_event(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_adobecampaigneventmetadata content_library_adob_updated_by_id_19f8b486_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_adobecampaigneventmetadata
    ADD CONSTRAINT content_library_adob_updated_by_id_19f8b486_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_application content_library_appl_cp_client_id_abb31c95_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_application
    ADD CONSTRAINT content_library_appl_cp_client_id_abb31c95_fk_content_l FOREIGN KEY (cp_client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_application content_library_appl_user_id_8c388a30_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_application
    ADD CONSTRAINT content_library_appl_user_id_8c388a30_fk_content_l FOREIGN KEY (user_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_audience content_library_audi_client_id_f95258dd_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_audience
    ADD CONSTRAINT content_library_audi_client_id_f95258dd_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_audience content_library_audi_created_by_id_f353e83a_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_audience
    ADD CONSTRAINT content_library_audi_created_by_id_f353e83a_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_audience content_library_audi_updated_by_id_a9b392d7_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_audience
    ADD CONSTRAINT content_library_audi_updated_by_id_a9b392d7_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_availableproductcollection_product_values content_library_avai_availableproductcoll_68f6f7e5_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_availableproductcollection_product_values
    ADD CONSTRAINT content_library_avai_availableproductcoll_68f6f7e5_fk_content_l FOREIGN KEY (availableproductcollection_id) REFERENCES public.content_library_availableproductcollection(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_availability content_library_avai_created_by_id_0634f66c_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_availability
    ADD CONSTRAINT content_library_avai_created_by_id_0634f66c_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_availableproductcollection content_library_avai_created_by_id_e00a14f2_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_availableproductcollection
    ADD CONSTRAINT content_library_avai_created_by_id_e00a14f2_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_availability content_library_avai_creative_id_b53939b3_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_availability
    ADD CONSTRAINT content_library_avai_creative_id_b53939b3_fk_content_l FOREIGN KEY (creative_id) REFERENCES public.content_library_creative(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_availableproductcollection_product_values content_library_avai_productvalue_id_3c683ec0_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_availableproductcollection_product_values
    ADD CONSTRAINT content_library_avai_productvalue_id_3c683ec0_fk_content_l FOREIGN KEY (productvalue_id) REFERENCES public.content_library_productvalue(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_availableproductcollection content_library_avai_updated_by_id_6ed41dd6_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_availableproductcollection
    ADD CONSTRAINT content_library_avai_updated_by_id_6ed41dd6_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_availability content_library_avai_updated_by_id_dee8ab29_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_availability
    ADD CONSTRAINT content_library_avai_updated_by_id_dee8ab29_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_basetemplate content_library_base_body_id_0a5bd0dd_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_basetemplate
    ADD CONSTRAINT content_library_base_body_id_0a5bd0dd_fk_content_l FOREIGN KEY (body_id) REFERENCES public.content_library_htmlbundle(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_basetemplate content_library_base_client_id_10d6847d_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_basetemplate
    ADD CONSTRAINT content_library_base_client_id_10d6847d_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_baseexperiment content_library_base_client_id_4c17d4cb_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_baseexperiment
    ADD CONSTRAINT content_library_base_client_id_4c17d4cb_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_basetemplate content_library_base_created_by_id_27245109_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_basetemplate
    ADD CONSTRAINT content_library_base_created_by_id_27245109_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_basetreatment content_library_base_created_by_id_ce86479f_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_basetreatment
    ADD CONSTRAINT content_library_base_created_by_id_ce86479f_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_baseexperiment content_library_base_created_by_id_d1a493fa_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_baseexperiment
    ADD CONSTRAINT content_library_base_created_by_id_d1a493fa_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_baseexperiment content_library_base_polymorphic_ctype_id_48130268_fk_django_co; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_baseexperiment
    ADD CONSTRAINT content_library_base_polymorphic_ctype_id_48130268_fk_django_co FOREIGN KEY (polymorphic_ctype_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_basetreatment content_library_base_polymorphic_ctype_id_4ebcfb5a_fk_django_co; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_basetreatment
    ADD CONSTRAINT content_library_base_polymorphic_ctype_id_4ebcfb5a_fk_django_co FOREIGN KEY (polymorphic_ctype_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_basetreatment content_library_base_updated_by_id_3e963391_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_basetreatment
    ADD CONSTRAINT content_library_base_updated_by_id_3e963391_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_baseexperiment content_library_base_updated_by_id_4624af0c_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_baseexperiment
    ADD CONSTRAINT content_library_base_updated_by_id_4624af0c_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_basetemplate content_library_base_updated_by_id_cac39035_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_basetemplate
    ADD CONSTRAINT content_library_base_updated_by_id_cac39035_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_bodytemplate content_library_body_base_template_id_4c64ec4c_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_bodytemplate
    ADD CONSTRAINT content_library_body_base_template_id_4c64ec4c_fk_content_l FOREIGN KEY (base_template_id) REFERENCES public.content_library_basetemplate(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_bodytemplate content_library_body_body_id_38841aae_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_bodytemplate
    ADD CONSTRAINT content_library_body_body_id_38841aae_fk_content_l FOREIGN KEY (body_id) REFERENCES public.content_library_htmlbundle(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_bodytemplatecontentblock content_library_body_body_template_id_8dcb42fe_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_bodytemplatecontentblock
    ADD CONSTRAINT content_library_body_body_template_id_8dcb42fe_fk_content_l FOREIGN KEY (body_template_id) REFERENCES public.content_library_bodytemplate(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_bodytemplatecontentblock content_library_body_content_block_id_a903e2c2_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_bodytemplatecontentblock
    ADD CONSTRAINT content_library_body_content_block_id_a903e2c2_fk_content_l FOREIGN KEY (content_block_id) REFERENCES public.content_library_contentblock(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_cheetahdigitallinkmetadata content_library_chee_cheetah_digital_id_746d0616_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitallinkmetadata
    ADD CONSTRAINT content_library_chee_cheetah_digital_id_746d0616_fk_content_l FOREIGN KEY (cheetah_digital_id) REFERENCES public.content_library_cheetahdigital(emailserviceprovider_ptr_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_cheetahdigitalstaticcontentblockdocument content_library_chee_content_block_id_4eeb2028_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitalstaticcontentblockdocument
    ADD CONSTRAINT content_library_chee_content_block_id_4eeb2028_fk_content_l FOREIGN KEY (content_block_id) REFERENCES public.content_library_contentblock(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_cheetahdigitalcreativecontentblockdocument content_library_chee_content_block_id_5bcc3779_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitalcreativecontentblockdocument
    ADD CONSTRAINT content_library_chee_content_block_id_5bcc3779_fk_content_l FOREIGN KEY (content_block_id) REFERENCES public.content_library_contentblock(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_cheetahdigitalclientconfig content_library_chee_created_by_id_293cb33b_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitalclientconfig
    ADD CONSTRAINT content_library_chee_created_by_id_293cb33b_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_cheetahdigitalcreativedocument content_library_chee_created_by_id_2ae1fc72_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitalcreativedocument
    ADD CONSTRAINT content_library_chee_created_by_id_2ae1fc72_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_cheetahdigitaleventmetadata content_library_chee_created_by_id_32bbfa7d_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitaleventmetadata
    ADD CONSTRAINT content_library_chee_created_by_id_32bbfa7d_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_cheetahdigitalcreativecontentblockdocument content_library_chee_created_by_id_4f9c07bb_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitalcreativecontentblockdocument
    ADD CONSTRAINT content_library_chee_created_by_id_4f9c07bb_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_cheetahdigitalstaticcontentblockdocument content_library_chee_created_by_id_804fdccc_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitalstaticcontentblockdocument
    ADD CONSTRAINT content_library_chee_created_by_id_804fdccc_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_cheetahdigitalcreativediscountofferdocument content_library_chee_created_by_id_e8c5fedf_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitalcreativediscountofferdocument
    ADD CONSTRAINT content_library_chee_created_by_id_e8c5fedf_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_cheetahdigitalcreativedocument content_library_chee_creative_id_0ee786fa_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitalcreativedocument
    ADD CONSTRAINT content_library_chee_creative_id_0ee786fa_fk_content_l FOREIGN KEY (creative_id) REFERENCES public.content_library_creative(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_cheetahdigitalcreativecontentblockdocument content_library_chee_creative_id_c2e65ce8_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitalcreativecontentblockdocument
    ADD CONSTRAINT content_library_chee_creative_id_c2e65ce8_fk_content_l FOREIGN KEY (creative_id) REFERENCES public.content_library_creative(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_cheetahdigitalcreativediscountofferdocument content_library_chee_document_id_5ffccc63_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitalcreativediscountofferdocument
    ADD CONSTRAINT content_library_chee_document_id_5ffccc63_fk_content_l FOREIGN KEY (document_id) REFERENCES public.content_library_cheetahdigitalcreativedocument(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_cheetahdigital content_library_chee_emailserviceprovider_56b93313_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigital
    ADD CONSTRAINT content_library_chee_emailserviceprovider_56b93313_fk_content_l FOREIGN KEY (emailserviceprovider_ptr_id) REFERENCES public.content_library_emailserviceprovider(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_cheetahdigitalclientconfig content_library_chee_esp_id_5dcd4168_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitalclientconfig
    ADD CONSTRAINT content_library_chee_esp_id_5dcd4168_fk_content_l FOREIGN KEY (esp_id) REFERENCES public.content_library_emailserviceprovider(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_cheetahdigitaleventmetadata content_library_chee_event_id_b6bac470_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitaleventmetadata
    ADD CONSTRAINT content_library_chee_event_id_b6bac470_fk_content_l FOREIGN KEY (event_id) REFERENCES public.content_library_event(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_cheetahdigitallinkmetadata content_library_chee_link_id_7698ea90_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitallinkmetadata
    ADD CONSTRAINT content_library_chee_link_id_7698ea90_fk_content_l FOREIGN KEY (link_id) REFERENCES public.content_library_link(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_cheetahdigitalcreativediscountofferdocument content_library_chee_promotion_redemption_1039038b_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitalcreativediscountofferdocument
    ADD CONSTRAINT content_library_chee_promotion_redemption_1039038b_fk_content_l FOREIGN KEY (promotion_redemption_id) REFERENCES public.content_library_promotionredemption(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_cheetahdigitalstaticcontentblockdocument content_library_chee_updated_by_id_0d4f8a79_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitalstaticcontentblockdocument
    ADD CONSTRAINT content_library_chee_updated_by_id_0d4f8a79_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_cheetahdigitalcreativecontentblockdocument content_library_chee_updated_by_id_19a63dae_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitalcreativecontentblockdocument
    ADD CONSTRAINT content_library_chee_updated_by_id_19a63dae_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_cheetahdigitaleventmetadata content_library_chee_updated_by_id_4ad0bcf0_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitaleventmetadata
    ADD CONSTRAINT content_library_chee_updated_by_id_4ad0bcf0_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_cheetahdigitalcreativedocument content_library_chee_updated_by_id_6d2050e8_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitalcreativedocument
    ADD CONSTRAINT content_library_chee_updated_by_id_6d2050e8_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_cheetahdigitalcreativediscountofferdocument content_library_chee_updated_by_id_7138475f_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitalcreativediscountofferdocument
    ADD CONSTRAINT content_library_chee_updated_by_id_7138475f_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_cheetahdigitalclientconfig content_library_chee_updated_by_id_754663b2_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_cheetahdigitalclientconfig
    ADD CONSTRAINT content_library_chee_updated_by_id_754663b2_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_clientconfiguration content_library_clie_client_id_72523e63_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_clientconfiguration
    ADD CONSTRAINT content_library_clie_client_id_72523e63_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_clientreuserule content_library_clie_client_id_9b4c9632_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_clientreuserule
    ADD CONSTRAINT content_library_clie_client_id_9b4c9632_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_clientreuserule content_library_clie_created_by_id_6de36490_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_clientreuserule
    ADD CONSTRAINT content_library_clie_created_by_id_6de36490_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_clientconfiguration content_library_clie_created_by_id_e185001a_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_clientconfiguration
    ADD CONSTRAINT content_library_clie_created_by_id_e185001a_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_clientconfiguration content_library_clie_default_content_pers_962b05a4_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_clientconfiguration
    ADD CONSTRAINT content_library_clie_default_content_pers_962b05a4_fk_content_l FOREIGN KEY (default_content_personalization_model_id) REFERENCES public.content_library_contentpersonalizationmodel(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_clientconfiguration content_library_clie_logo_header_id_09c1950c_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_clientconfiguration
    ADD CONSTRAINT content_library_clie_logo_header_id_09c1950c_fk_content_l FOREIGN KEY (logo_header_id) REFERENCES public.content_library_image(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_clientconfiguration content_library_clie_logo_square_id_b977ac10_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_clientconfiguration
    ADD CONSTRAINT content_library_clie_logo_square_id_b977ac10_fk_content_l FOREIGN KEY (logo_square_id) REFERENCES public.content_library_image(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_clientuser content_library_clie_organization_id_0fc260a3_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_clientuser
    ADD CONSTRAINT content_library_clie_organization_id_0fc260a3_fk_content_l FOREIGN KEY (organization_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_clientuseradmin content_library_clie_organization_id_30f5e220_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_clientuseradmin
    ADD CONSTRAINT content_library_clie_organization_id_30f5e220_fk_content_l FOREIGN KEY (organization_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_clientuseradmin content_library_clie_organization_user_id_a1ade76e_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_clientuseradmin
    ADD CONSTRAINT content_library_clie_organization_user_id_a1ade76e_fk_content_l FOREIGN KEY (organization_user_id) REFERENCES public.content_library_clientuser(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_clientconfiguration content_library_clie_updated_by_id_77b2e3f8_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_clientconfiguration
    ADD CONSTRAINT content_library_clie_updated_by_id_77b2e3f8_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_clientreuserule content_library_clie_updated_by_id_cde56579_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_clientreuserule
    ADD CONSTRAINT content_library_clie_updated_by_id_cde56579_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_clientuser content_library_clie_user_id_e884f9ba_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_clientuser
    ADD CONSTRAINT content_library_clie_user_id_e884f9ba_fk_content_l FOREIGN KEY (user_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_contentpersonalizationmodelexperiment content_library_cont_baseexperiment_ptr_i_7cd56cdf_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentpersonalizationmodelexperiment
    ADD CONSTRAINT content_library_cont_baseexperiment_ptr_i_7cd56cdf_fk_content_l FOREIGN KEY (baseexperiment_ptr_id) REFERENCES public.content_library_baseexperiment(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_contentpersonalizationmodeltreatment content_library_cont_basetreatment_ptr_id_92f280e8_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentpersonalizationmodeltreatment
    ADD CONSTRAINT content_library_cont_basetreatment_ptr_id_92f280e8_fk_content_l FOREIGN KEY (basetreatment_ptr_id) REFERENCES public.content_library_basetreatment(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_contentblock content_library_cont_client_id_c57b1221_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentblock
    ADD CONSTRAINT content_library_cont_client_id_c57b1221_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_contentblocktemplatetag content_library_cont_content_block_id_10afc397_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentblocktemplatetag
    ADD CONSTRAINT content_library_cont_content_block_id_10afc397_fk_content_l FOREIGN KEY (content_block_id) REFERENCES public.content_library_contentblock(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_contentblockcreativeversion content_library_cont_content_block_id_b51353ee_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentblockcreativeversion
    ADD CONSTRAINT content_library_cont_content_block_id_b51353ee_fk_content_l FOREIGN KEY (content_block_id) REFERENCES public.content_library_contentblock(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_contentpersonalizationmodeltreatment content_library_cont_content_personalizat_5fb658c3_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentpersonalizationmodeltreatment
    ADD CONSTRAINT content_library_cont_content_personalizat_5fb658c3_fk_content_l FOREIGN KEY (content_personalization_model_id) REFERENCES public.content_library_contentpersonalizationmodel(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_contentblock content_library_cont_created_by_id_09923cb6_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentblock
    ADD CONSTRAINT content_library_cont_created_by_id_09923cb6_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_contentblocktemplatetag content_library_cont_created_by_id_2bf7c376_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentblocktemplatetag
    ADD CONSTRAINT content_library_cont_created_by_id_2bf7c376_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_contentpersonalizationmodelvariant content_library_cont_created_by_id_430a3f8a_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentpersonalizationmodelvariant
    ADD CONSTRAINT content_library_cont_created_by_id_430a3f8a_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_contentblockcreativeversion content_library_cont_creative_id_24aa3d04_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentblockcreativeversion
    ADD CONSTRAINT content_library_cont_creative_id_24aa3d04_fk_content_l FOREIGN KEY (creative_id) REFERENCES public.content_library_creative(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_contentpersonalizationmodelvariant content_library_cont_event_id_cc121f91_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentpersonalizationmodelvariant
    ADD CONSTRAINT content_library_cont_event_id_cc121f91_fk_content_l FOREIGN KEY (event_id) REFERENCES public.content_library_event(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_contentpersonalizationmodeltreatment content_library_cont_experiment_id_7467bf9b_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentpersonalizationmodeltreatment
    ADD CONSTRAINT content_library_cont_experiment_id_7467bf9b_fk_content_l FOREIGN KEY (experiment_id) REFERENCES public.content_library_contentpersonalizationmodelexperiment(baseexperiment_ptr_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_contentblock content_library_cont_html_bundle_id_3eaf9d2b_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentblock
    ADD CONSTRAINT content_library_cont_html_bundle_id_3eaf9d2b_fk_content_l FOREIGN KEY (html_bundle_id) REFERENCES public.content_library_htmlbundle(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_contentpersonalizationmodelvariant content_library_cont_model_id_8ba8fc24_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentpersonalizationmodelvariant
    ADD CONSTRAINT content_library_cont_model_id_8ba8fc24_fk_content_l FOREIGN KEY (model_id) REFERENCES public.content_library_contentpersonalizationmodel(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_contentblocktemplatetag content_library_cont_template_tag_id_60a5d5e8_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentblocktemplatetag
    ADD CONSTRAINT content_library_cont_template_tag_id_60a5d5e8_fk_content_l FOREIGN KEY (template_tag_id) REFERENCES public.content_library_templatetag(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_contentpersonalizationmodelvariant content_library_cont_treatment_id_01fd4288_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentpersonalizationmodelvariant
    ADD CONSTRAINT content_library_cont_treatment_id_01fd4288_fk_content_l FOREIGN KEY (treatment_id) REFERENCES public.content_library_contentpersonalizationmodeltreatment(basetreatment_ptr_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_contentblock content_library_cont_updated_by_id_0b31637e_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentblock
    ADD CONSTRAINT content_library_cont_updated_by_id_0b31637e_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_contentblocktemplatetag content_library_cont_updated_by_id_0cdc89d4_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentblocktemplatetag
    ADD CONSTRAINT content_library_cont_updated_by_id_0cdc89d4_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_contentpersonalizationmodelvariant content_library_cont_updated_by_id_ba1c93d1_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentpersonalizationmodelvariant
    ADD CONSTRAINT content_library_cont_updated_by_id_ba1c93d1_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_creativeattributechoice content_library_crea_attribute_id_bc12d687_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creativeattributechoice
    ADD CONSTRAINT content_library_crea_attribute_id_bc12d687_fk_content_l FOREIGN KEY (attribute_id) REFERENCES public.content_library_creativeattribute(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_creative content_library_crea_audience_id_2426d9c0_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creative
    ADD CONSTRAINT content_library_crea_audience_id_2426d9c0_fk_content_l FOREIGN KEY (audience_id) REFERENCES public.content_library_audience(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_creativeattribute content_library_crea_client_id_42e16f4e_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creativeattribute
    ADD CONSTRAINT content_library_crea_client_id_42e16f4e_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_creative content_library_crea_client_id_b4c971f8_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creative
    ADD CONSTRAINT content_library_crea_client_id_b4c971f8_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_creativecontentblockdocument content_library_crea_content_block_id_4c672649_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creativecontentblockdocument
    ADD CONSTRAINT content_library_crea_content_block_id_4c672649_fk_content_l FOREIGN KEY (content_block_id) REFERENCES public.content_library_contentblock(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_creativereuserule content_library_crea_created_by_id_3a52faef_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creativereuserule
    ADD CONSTRAINT content_library_crea_created_by_id_3a52faef_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_creativeattribute content_library_crea_created_by_id_45c48e6f_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creativeattribute
    ADD CONSTRAINT content_library_crea_created_by_id_45c48e6f_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_creativecontentblockdocument content_library_crea_created_by_id_5f1dbd8d_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creativecontentblockdocument
    ADD CONSTRAINT content_library_crea_created_by_id_5f1dbd8d_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_creative content_library_crea_created_by_id_d13c712e_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creative
    ADD CONSTRAINT content_library_crea_created_by_id_d13c712e_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_creative_tags content_library_crea_creative_id_3f790aa3_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creative_tags
    ADD CONSTRAINT content_library_crea_creative_id_3f790aa3_fk_content_l FOREIGN KEY (creative_id) REFERENCES public.content_library_creative(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_creativecontentblockdocument content_library_crea_creative_id_a1803c6d_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creativecontentblockdocument
    ADD CONSTRAINT content_library_crea_creative_id_a1803c6d_fk_content_l FOREIGN KEY (creative_id) REFERENCES public.content_library_creative(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_creativepromotion content_library_crea_creative_id_caf1233b_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creativepromotion
    ADD CONSTRAINT content_library_crea_creative_id_caf1233b_fk_content_l FOREIGN KEY (creative_id) REFERENCES public.content_library_creative(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_creativereuserule content_library_crea_creative_id_ce9168f8_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creativereuserule
    ADD CONSTRAINT content_library_crea_creative_id_ce9168f8_fk_content_l FOREIGN KEY (creative_id) REFERENCES public.content_library_creative(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_creativestats content_library_crea_creative_id_e62c334b_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creativestats
    ADD CONSTRAINT content_library_crea_creative_id_e62c334b_fk_content_l FOREIGN KEY (creative_id) REFERENCES public.content_library_creative(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_creative_product_collections content_library_crea_creative_id_eac423c0_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creative_product_collections
    ADD CONSTRAINT content_library_crea_creative_id_eac423c0_fk_content_l FOREIGN KEY (creative_id) REFERENCES public.content_library_creative(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_creative content_library_crea_disclaimer_image_id_4d7b3014_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creative
    ADD CONSTRAINT content_library_crea_disclaimer_image_id_4d7b3014_fk_content_l FOREIGN KEY (disclaimer_image_id) REFERENCES public.content_library_image(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_creative content_library_crea_disclaimer_link_id_c9742249_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creative
    ADD CONSTRAINT content_library_crea_disclaimer_link_id_c9742249_fk_content_l FOREIGN KEY (disclaimer_link_id) REFERENCES public.content_library_link(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_creative_prohibited_creatives content_library_crea_from_creative_id_e4167acb_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creative_prohibited_creatives
    ADD CONSTRAINT content_library_crea_from_creative_id_e4167acb_fk_content_l FOREIGN KEY (from_creative_id) REFERENCES public.content_library_creative(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_creative content_library_crea_preheader_link_id_9b586c38_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creative
    ADD CONSTRAINT content_library_crea_preheader_link_id_9b586c38_fk_content_l FOREIGN KEY (preheader_link_id) REFERENCES public.content_library_link(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_creative_product_collections content_library_crea_productcollection_id_0ebdd079_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creative_product_collections
    ADD CONSTRAINT content_library_crea_productcollection_id_0ebdd079_fk_content_l FOREIGN KEY (productcollection_id) REFERENCES public.content_library_productcollection(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_creative content_library_crea_promotion_card_id_e1a37b8a_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creative
    ADD CONSTRAINT content_library_crea_promotion_card_id_e1a37b8a_fk_content_l FOREIGN KEY (promotion_card_id) REFERENCES public.content_library_image(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_creativepromotion content_library_crea_promotion_id_eb18d4cb_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creativepromotion
    ADD CONSTRAINT content_library_crea_promotion_id_eb18d4cb_fk_content_l FOREIGN KEY (promotion_id) REFERENCES public.content_library_promotion(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_creative_tags content_library_crea_tag_id_1dca22ca_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creative_tags
    ADD CONSTRAINT content_library_crea_tag_id_1dca22ca_fk_content_l FOREIGN KEY (tag_id) REFERENCES public.content_library_tag(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_creative_prohibited_creatives content_library_crea_to_creative_id_6450fc1b_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creative_prohibited_creatives
    ADD CONSTRAINT content_library_crea_to_creative_id_6450fc1b_fk_content_l FOREIGN KEY (to_creative_id) REFERENCES public.content_library_creative(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_creativeattribute content_library_crea_updated_by_id_3487042e_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creativeattribute
    ADD CONSTRAINT content_library_crea_updated_by_id_3487042e_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_creativereuserule content_library_crea_updated_by_id_55192ec8_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creativereuserule
    ADD CONSTRAINT content_library_crea_updated_by_id_55192ec8_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_creativecontentblockdocument content_library_crea_updated_by_id_7df50456_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creativecontentblockdocument
    ADD CONSTRAINT content_library_crea_updated_by_id_7df50456_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_creative content_library_crea_updated_by_id_f5a8281d_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_creative
    ADD CONSTRAINT content_library_crea_updated_by_id_f5a8281d_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_discountoffer content_library_disc_created_by_id_8f243674_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_discountoffer
    ADD CONSTRAINT content_library_disc_created_by_id_8f243674_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_discountoffer content_library_disc_updated_by_id_6540cf87_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_discountoffer
    ADD CONSTRAINT content_library_disc_updated_by_id_6540cf87_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_document content_library_docu_content_block_id_7b98ba6e_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_document
    ADD CONSTRAINT content_library_docu_content_block_id_7b98ba6e_fk_content_l FOREIGN KEY (content_block_id) REFERENCES public.content_library_contentblock(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_document content_library_docu_created_by_id_62ad484d_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_document
    ADD CONSTRAINT content_library_docu_created_by_id_62ad484d_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_document content_library_docu_creative_id_b40b302f_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_document
    ADD CONSTRAINT content_library_docu_creative_id_b40b302f_fk_content_l FOREIGN KEY (creative_id) REFERENCES public.content_library_creative(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_document content_library_docu_promotion_redemption_48c744eb_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_document
    ADD CONSTRAINT content_library_docu_promotion_redemption_48c744eb_fk_content_l FOREIGN KEY (promotion_redemption_id) REFERENCES public.content_library_promotionredemption(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_document content_library_docu_updated_by_id_2d8ba6e8_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_document
    ADD CONSTRAINT content_library_docu_updated_by_id_2d8ba6e8_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_dynamicsectionvariant content_library_dyna_creatives_variant_id_65abb264_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_dynamicsectionvariant
    ADD CONSTRAINT content_library_dyna_creatives_variant_id_65abb264_fk_content_l FOREIGN KEY (creatives_variant_id) REFERENCES public.content_library_eligiblecreativesvariant(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_dynamicsectionvariant content_library_dyna_event_audience_id_192b13f0_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_dynamicsectionvariant
    ADD CONSTRAINT content_library_dyna_event_audience_id_192b13f0_fk_content_l FOREIGN KEY (event_audience_id) REFERENCES public.content_library_eventaudience(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_dynamicsectionvariant content_library_dyna_section_id_b91ebbfb_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_dynamicsectionvariant
    ADD CONSTRAINT content_library_dyna_section_id_b91ebbfb_fk_content_l FOREIGN KEY (section_id) REFERENCES public.content_library_section(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eligiblecreativesexperiment content_library_elig_baseexperiment_ptr_i_992aa134_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eligiblecreativesexperiment
    ADD CONSTRAINT content_library_elig_baseexperiment_ptr_i_992aa134_fk_content_l FOREIGN KEY (baseexperiment_ptr_id) REFERENCES public.content_library_baseexperiment(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eligiblecreativestreatment content_library_elig_basetreatment_ptr_id_cac37090_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eligiblecreativestreatment
    ADD CONSTRAINT content_library_elig_basetreatment_ptr_id_cac37090_fk_content_l FOREIGN KEY (basetreatment_ptr_id) REFERENCES public.content_library_basetreatment(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eligiblecreativesvariant_treatments content_library_elig_eligiblecreativestre_b3c1ec1f_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eligiblecreativesvariant_treatments
    ADD CONSTRAINT content_library_elig_eligiblecreativestre_b3c1ec1f_fk_content_l FOREIGN KEY (eligiblecreativestreatment_id) REFERENCES public.content_library_eligiblecreativestreatment(basetreatment_ptr_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eligiblecreativesvariant_treatments content_library_elig_eligiblecreativesvar_002d87a1_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eligiblecreativesvariant_treatments
    ADD CONSTRAINT content_library_elig_eligiblecreativesvar_002d87a1_fk_content_l FOREIGN KEY (eligiblecreativesvariant_id) REFERENCES public.content_library_eligiblecreativesvariant(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eligiblecreativesvariant content_library_elig_event_id_fa443f0b_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eligiblecreativesvariant
    ADD CONSTRAINT content_library_elig_event_id_fa443f0b_fk_content_l FOREIGN KEY (event_id) REFERENCES public.content_library_event(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eligiblecreativestreatment content_library_elig_experiment_id_d3753aeb_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eligiblecreativestreatment
    ADD CONSTRAINT content_library_elig_experiment_id_d3753aeb_fk_content_l FOREIGN KEY (experiment_id) REFERENCES public.content_library_eligiblecreativesexperiment(baseexperiment_ptr_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_emailserviceprovider content_library_emai_cp_client_id_bb623a30_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_emailserviceprovider
    ADD CONSTRAINT content_library_emai_cp_client_id_bb623a30_fk_content_l FOREIGN KEY (cp_client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventattributechoice content_library_even_attribute_id_9704516b_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventattributechoice
    ADD CONSTRAINT content_library_even_attribute_id_9704516b_fk_content_l FOREIGN KEY (attribute_id) REFERENCES public.content_library_eventattribute(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventaudience content_library_even_audience_id_9d932422_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventaudience
    ADD CONSTRAINT content_library_even_audience_id_9d932422_fk_content_l FOREIGN KEY (audience_id) REFERENCES public.content_library_audience(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_event content_library_even_base_template_id_9fdd99fb_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_event
    ADD CONSTRAINT content_library_even_base_template_id_9fdd99fb_fk_content_l FOREIGN KEY (base_template_id) REFERENCES public.content_library_basetemplate(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventattribute content_library_even_client_id_36b827ec_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventattribute
    ADD CONSTRAINT content_library_even_client_id_36b827ec_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_event content_library_even_client_id_cadc2dc3_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_event
    ADD CONSTRAINT content_library_even_client_id_cadc2dc3_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventcontentblockcreativestats content_library_even_content_block_id_56d61767_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventcontentblockcreativestats
    ADD CONSTRAINT content_library_even_content_block_id_56d61767_fk_content_l FOREIGN KEY (content_block_id) REFERENCES public.content_library_contentblock(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventacousticcampaignconfig content_library_even_created_by_id_425c3b45_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventacousticcampaignconfig
    ADD CONSTRAINT content_library_even_created_by_id_425c3b45_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventattributechoicecheetahdigitalselectionid content_library_even_created_by_id_53d56566_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventattributechoicecheetahdigitalselectionid
    ADD CONSTRAINT content_library_even_created_by_id_53d56566_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventsalesforcemarketingcloudconfig content_library_even_created_by_id_5ee445be_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventsalesforcemarketingcloudconfig
    ADD CONSTRAINT content_library_even_created_by_id_5ee445be_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventattributechoice content_library_even_created_by_id_617d6d8a_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventattributechoice
    ADD CONSTRAINT content_library_even_created_by_id_617d6d8a_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventoracleresponsysconfig content_library_even_created_by_id_804ba9b8_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventoracleresponsysconfig
    ADD CONSTRAINT content_library_even_created_by_id_804ba9b8_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_event content_library_even_created_by_id_8e4b7c64_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_event
    ADD CONSTRAINT content_library_even_created_by_id_8e4b7c64_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventattributecheetahdigitaloptionid content_library_even_created_by_id_ba0b8118_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventattributecheetahdigitaloptionid
    ADD CONSTRAINT content_library_even_created_by_id_ba0b8118_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventattribute content_library_even_created_by_id_e14de076_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventattribute
    ADD CONSTRAINT content_library_even_created_by_id_e14de076_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventattributeoracleresponsyscampaignvariable content_library_even_created_by_id_fc6f1668_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventattributeoracleresponsyscampaignvariable
    ADD CONSTRAINT content_library_even_created_by_id_fc6f1668_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventattributechoicecheetahdigitalselectionid content_library_even_event_attribute_choi_1dbd74e3_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventattributechoicecheetahdigitalselectionid
    ADD CONSTRAINT content_library_even_event_attribute_choi_1dbd74e3_fk_content_l FOREIGN KEY (event_attribute_choice_id) REFERENCES public.content_library_eventattributechoice(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventattributeoracleresponsyscampaignvariable content_library_even_event_attribute_id_10bd5851_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventattributeoracleresponsyscampaignvariable
    ADD CONSTRAINT content_library_even_event_attribute_id_10bd5851_fk_content_l FOREIGN KEY (event_attribute_id) REFERENCES public.content_library_eventattribute(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventattributecheetahdigitaloptionid content_library_even_event_attribute_id_8f96cd86_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventattributecheetahdigitaloptionid
    ADD CONSTRAINT content_library_even_event_attribute_id_8f96cd86_fk_content_l FOREIGN KEY (event_attribute_id) REFERENCES public.content_library_eventattribute(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventtrackingpixel content_library_even_event_id_16a1c12e_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventtrackingpixel
    ADD CONSTRAINT content_library_even_event_id_16a1c12e_fk_content_l FOREIGN KEY (event_id) REFERENCES public.content_library_event(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventacousticcampaignconfig content_library_even_event_id_1838fc20_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventacousticcampaignconfig
    ADD CONSTRAINT content_library_even_event_id_1838fc20_fk_content_l FOREIGN KEY (event_id) REFERENCES public.content_library_event(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventtasklog content_library_even_event_id_1ea917e1_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventtasklog
    ADD CONSTRAINT content_library_even_event_id_1ea917e1_fk_content_l FOREIGN KEY (event_id) REFERENCES public.content_library_event(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventcreativestats content_library_even_event_id_3a27720d_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventcreativestats
    ADD CONSTRAINT content_library_even_event_id_3a27720d_fk_content_l FOREIGN KEY (event_id) REFERENCES public.content_library_event(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventrun content_library_even_event_id_3cf4563a_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventrun
    ADD CONSTRAINT content_library_even_event_id_3cf4563a_fk_content_l FOREIGN KEY (event_id) REFERENCES public.content_library_event(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventstats content_library_even_event_id_3fc54613_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventstats
    ADD CONSTRAINT content_library_even_event_id_3fc54613_fk_content_l FOREIGN KEY (event_id) REFERENCES public.content_library_event(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventsalesforcemarketingcloudconfig content_library_even_event_id_9d7bbb21_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventsalesforcemarketingcloudconfig
    ADD CONSTRAINT content_library_even_event_id_9d7bbb21_fk_content_l FOREIGN KEY (event_id) REFERENCES public.content_library_event(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventexperimentstats content_library_even_event_id_ab46c945_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventexperimentstats
    ADD CONSTRAINT content_library_even_event_id_ab46c945_fk_content_l FOREIGN KEY (event_id) REFERENCES public.content_library_event(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventstatus content_library_even_event_id_babfc1cc_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventstatus
    ADD CONSTRAINT content_library_even_event_id_babfc1cc_fk_content_l FOREIGN KEY (event_id) REFERENCES public.content_library_event(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventoracleresponsysconfig content_library_even_event_id_bcc87b88_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventoracleresponsysconfig
    ADD CONSTRAINT content_library_even_event_id_bcc87b88_fk_content_l FOREIGN KEY (event_id) REFERENCES public.content_library_event(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_event_tags content_library_even_event_id_bdc79282_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_event_tags
    ADD CONSTRAINT content_library_even_event_id_bdc79282_fk_content_l FOREIGN KEY (event_id) REFERENCES public.content_library_event(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventcontentblockstats content_library_even_event_id_c865be53_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventcontentblockstats
    ADD CONSTRAINT content_library_even_event_id_c865be53_fk_content_l FOREIGN KEY (event_id) REFERENCES public.content_library_event(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventaudience content_library_even_event_id_de0691fd_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventaudience
    ADD CONSTRAINT content_library_even_event_id_de0691fd_fk_content_l FOREIGN KEY (event_id) REFERENCES public.content_library_event(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventcontentblockcreativestats content_library_even_event_id_e84a944c_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventcontentblockcreativestats
    ADD CONSTRAINT content_library_even_event_id_e84a944c_fk_content_l FOREIGN KEY (event_id) REFERENCES public.content_library_event(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventoracleresponsysconfig_suppressions content_library_even_eventoracleresponsys_3dcab5f3_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventoracleresponsysconfig_suppressions
    ADD CONSTRAINT content_library_even_eventoracleresponsys_3dcab5f3_fk_content_l FOREIGN KEY (eventoracleresponsysconfig_id) REFERENCES public.content_library_eventoracleresponsysconfig(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventoracleresponsysconfig_additional_data_13a0 content_library_even_eventoracleresponsys_b5eb2123_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventoracleresponsysconfig_additional_data_13a0
    ADD CONSTRAINT content_library_even_eventoracleresponsys_b5eb2123_fk_content_l FOREIGN KEY (eventoracleresponsysconfig_id) REFERENCES public.content_library_eventoracleresponsysconfig(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventsalesforcemarketingcloudconfig_suppresa376 content_library_even_eventsalesforcemarke_21d5d7d2_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventsalesforcemarketingcloudconfig_suppresa376
    ADD CONSTRAINT content_library_even_eventsalesforcemarke_21d5d7d2_fk_content_l FOREIGN KEY (eventsalesforcemarketingcloudconfig_id) REFERENCES public.content_library_eventsalesforcemarketingcloudconfig(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventacousticcampaignconfig content_library_even_from_address_id_99dbef13_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventacousticcampaignconfig
    ADD CONSTRAINT content_library_even_from_address_id_99dbef13_fk_content_l FOREIGN KEY (from_address_id) REFERENCES public.content_library_acousticcampaignfromaddress(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventacousticcampaignconfig content_library_even_from_name_id_39635b74_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventacousticcampaignconfig
    ADD CONSTRAINT content_library_even_from_name_id_39635b74_fk_content_l FOREIGN KEY (from_name_id) REFERENCES public.content_library_acousticcampaignfromname(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventoracleresponsysconfig content_library_even_marketing_program_id_e517290d_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventoracleresponsysconfig
    ADD CONSTRAINT content_library_even_marketing_program_id_e517290d_fk_content_l FOREIGN KEY (marketing_program_id) REFERENCES public.content_library_oracleresponsysmarketingprogram(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventoracleresponsysconfig content_library_even_marketing_strategy_i_261a90aa_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventoracleresponsysconfig
    ADD CONSTRAINT content_library_even_marketing_strategy_i_261a90aa_fk_content_l FOREIGN KEY (marketing_strategy_id) REFERENCES public.content_library_oracleresponsysmarketingstrategy(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventoracleresponsysconfig_additional_data_13a0 content_library_even_oracleresponsysaddit_2e690b16_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventoracleresponsysconfig_additional_data_13a0
    ADD CONSTRAINT content_library_even_oracleresponsysaddit_2e690b16_fk_content_l FOREIGN KEY (oracleresponsysadditionaldatasource_id) REFERENCES public.content_library_oracleresponsysadditionaldatasource(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventoracleresponsysconfig_suppressions content_library_even_oracleresponsyssuppr_9de47907_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventoracleresponsysconfig_suppressions
    ADD CONSTRAINT content_library_even_oracleresponsyssuppr_9de47907_fk_content_l FOREIGN KEY (oracleresponsyssuppression_id) REFERENCES public.content_library_oracleresponsyssuppression(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_event content_library_even_persado_campaign_id_3ad69923_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_event
    ADD CONSTRAINT content_library_even_persado_campaign_id_3ad69923_fk_content_l FOREIGN KEY (persado_campaign_id) REFERENCES public.content_library_persadocampaign(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventsalesforcemarketingcloudconfig content_library_even_publication_list_id_8e9b5d43_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventsalesforcemarketingcloudconfig
    ADD CONSTRAINT content_library_even_publication_list_id_8e9b5d43_fk_content_l FOREIGN KEY (publication_list_id) REFERENCES public.content_library_salesforcemarketingcloudpublicationlist(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventacousticcampaignconfig content_library_even_reply_to_id_e6bd9ab7_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventacousticcampaignconfig
    ADD CONSTRAINT content_library_even_reply_to_id_e6bd9ab7_fk_content_l FOREIGN KEY (reply_to_id) REFERENCES public.content_library_acousticcampaignreplyto(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventsalesforcemarketingcloudconfig_suppresa376 content_library_even_salesforcemarketingc_bd343078_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventsalesforcemarketingcloudconfig_suppresa376
    ADD CONSTRAINT content_library_even_salesforcemarketingc_bd343078_fk_content_l FOREIGN KEY (salesforcemarketingcloudsuppressiondataextension_id) REFERENCES public.content_library_salesforcemarketingcloudsuppressiondataexte91a1(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventsalesforcemarketingcloudconfig content_library_even_sender_profile_id_22c81e12_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventsalesforcemarketingcloudconfig
    ADD CONSTRAINT content_library_even_sender_profile_id_22c81e12_fk_content_l FOREIGN KEY (sender_profile_id) REFERENCES public.content_library_salesforcemarketingcloudsenderprofile(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventoracleresponsysconfig content_library_even_sender_profile_id_bc6220aa_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventoracleresponsysconfig
    ADD CONSTRAINT content_library_even_sender_profile_id_bc6220aa_fk_content_l FOREIGN KEY (sender_profile_id) REFERENCES public.content_library_oracleresponsyssenderprofile(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_event_tags content_library_even_tag_id_9af64c32_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_event_tags
    ADD CONSTRAINT content_library_even_tag_id_9af64c32_fk_content_l FOREIGN KEY (tag_id) REFERENCES public.content_library_tag(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_event content_library_even_template_id_ffcf881b_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_event
    ADD CONSTRAINT content_library_even_template_id_ffcf881b_fk_content_l FOREIGN KEY (template_id) REFERENCES public.content_library_template(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventsalesforcemarketingcloudconfig content_library_even_updated_by_id_0cd09014_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventsalesforcemarketingcloudconfig
    ADD CONSTRAINT content_library_even_updated_by_id_0cd09014_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventattributechoicecheetahdigitalselectionid content_library_even_updated_by_id_53af34b8_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventattributechoicecheetahdigitalselectionid
    ADD CONSTRAINT content_library_even_updated_by_id_53af34b8_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventattribute content_library_even_updated_by_id_63f1aab6_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventattribute
    ADD CONSTRAINT content_library_even_updated_by_id_63f1aab6_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventattributechoice content_library_even_updated_by_id_6d4b4245_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventattributechoice
    ADD CONSTRAINT content_library_even_updated_by_id_6d4b4245_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventacousticcampaignconfig content_library_even_updated_by_id_86c5340f_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventacousticcampaignconfig
    ADD CONSTRAINT content_library_even_updated_by_id_86c5340f_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_event content_library_even_updated_by_id_86dfa1b7_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_event
    ADD CONSTRAINT content_library_even_updated_by_id_86dfa1b7_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventattributecheetahdigitaloptionid content_library_even_updated_by_id_8b8a51b5_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventattributecheetahdigitaloptionid
    ADD CONSTRAINT content_library_even_updated_by_id_8b8a51b5_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventoracleresponsysconfig content_library_even_updated_by_id_b85a4210_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventoracleresponsysconfig
    ADD CONSTRAINT content_library_even_updated_by_id_b85a4210_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventattributeoracleresponsyscampaignvariable content_library_even_updated_by_id_cc52a2c4_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventattributeoracleresponsyscampaignvariable
    ADD CONSTRAINT content_library_even_updated_by_id_cc52a2c4_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_eventstatus content_library_even_user_id_d6cd515e_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_eventstatus
    ADD CONSTRAINT content_library_even_user_id_d6cd515e_fk_content_l FOREIGN KEY (user_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_footertemplate content_library_foot_base_template_id_c7e72ba6_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_footertemplate
    ADD CONSTRAINT content_library_foot_base_template_id_c7e72ba6_fk_content_l FOREIGN KEY (base_template_id) REFERENCES public.content_library_basetemplate(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_footertemplate content_library_foot_body_id_660328de_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_footertemplate
    ADD CONSTRAINT content_library_foot_body_id_660328de_fk_content_l FOREIGN KEY (body_id) REFERENCES public.content_library_htmlbundle(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_footertemplatecontentblock content_library_foot_content_block_id_95269a27_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_footertemplatecontentblock
    ADD CONSTRAINT content_library_foot_content_block_id_95269a27_fk_content_l FOREIGN KEY (content_block_id) REFERENCES public.content_library_contentblock(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_footertemplatecontentblock content_library_foot_footer_template_id_9f9390fb_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_footertemplatecontentblock
    ADD CONSTRAINT content_library_foot_footer_template_id_9f9390fb_fk_content_l FOREIGN KEY (footer_template_id) REFERENCES public.content_library_footertemplate(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_freegift content_library_free_created_by_id_0221e46a_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_freegift
    ADD CONSTRAINT content_library_free_created_by_id_0221e46a_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_freegift content_library_free_updated_by_id_75011214_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_freegift
    ADD CONSTRAINT content_library_free_updated_by_id_75011214_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_headertemplate content_library_head_base_template_id_35a1cd94_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_headertemplate
    ADD CONSTRAINT content_library_head_base_template_id_35a1cd94_fk_content_l FOREIGN KEY (base_template_id) REFERENCES public.content_library_basetemplate(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_headertemplate content_library_head_body_id_ddedf73b_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_headertemplate
    ADD CONSTRAINT content_library_head_body_id_ddedf73b_fk_content_l FOREIGN KEY (body_id) REFERENCES public.content_library_htmlbundle(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_headertemplatecontentblock content_library_head_content_block_id_dd77f560_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_headertemplatecontentblock
    ADD CONSTRAINT content_library_head_content_block_id_dd77f560_fk_content_l FOREIGN KEY (content_block_id) REFERENCES public.content_library_contentblock(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_headertemplatecontentblock content_library_head_header_template_id_500a582a_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_headertemplatecontentblock
    ADD CONSTRAINT content_library_head_header_template_id_500a582a_fk_content_l FOREIGN KEY (header_template_id) REFERENCES public.content_library_headertemplate(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_htmlbundle content_library_html_client_id_217e9e4c_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_htmlbundle
    ADD CONSTRAINT content_library_html_client_id_217e9e4c_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_htmlbundle content_library_html_created_by_id_6619470c_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_htmlbundle
    ADD CONSTRAINT content_library_html_created_by_id_6619470c_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_htmlbundleimage content_library_html_created_by_id_c0e4b8a3_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_htmlbundleimage
    ADD CONSTRAINT content_library_html_created_by_id_c0e4b8a3_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_htmlbundlelink content_library_html_html_bundle_id_1f853176_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_htmlbundlelink
    ADD CONSTRAINT content_library_html_html_bundle_id_1f853176_fk_content_l FOREIGN KEY (html_bundle_id) REFERENCES public.content_library_htmlbundle(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_htmlbundleimage content_library_html_html_bundle_id_c832f06a_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_htmlbundleimage
    ADD CONSTRAINT content_library_html_html_bundle_id_c832f06a_fk_content_l FOREIGN KEY (html_bundle_id) REFERENCES public.content_library_htmlbundle(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_htmlbundleimage content_library_html_image_id_0ead8e49_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_htmlbundleimage
    ADD CONSTRAINT content_library_html_image_id_0ead8e49_fk_content_l FOREIGN KEY (image_id) REFERENCES public.content_library_image(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_htmlbundlelink content_library_html_link_id_3e2ef908_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_htmlbundlelink
    ADD CONSTRAINT content_library_html_link_id_3e2ef908_fk_content_l FOREIGN KEY (link_id) REFERENCES public.content_library_link(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_htmlbundle content_library_html_updated_by_id_1682cdf6_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_htmlbundle
    ADD CONSTRAINT content_library_html_updated_by_id_1682cdf6_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_htmlbundleimage content_library_html_updated_by_id_b11d9e63_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_htmlbundleimage
    ADD CONSTRAINT content_library_html_updated_by_id_b11d9e63_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_imageslice content_library_imag_client_id_76e96698_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_imageslice
    ADD CONSTRAINT content_library_imag_client_id_76e96698_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_image content_library_imag_client_id_c3e417e2_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_image
    ADD CONSTRAINT content_library_imag_client_id_c3e417e2_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_imagelayout content_library_imag_client_id_dd0194f9_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_imagelayout
    ADD CONSTRAINT content_library_imag_client_id_dd0194f9_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_imagelayout content_library_imag_created_by_id_1af5c17e_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_imagelayout
    ADD CONSTRAINT content_library_imag_created_by_id_1af5c17e_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_image content_library_imag_created_by_id_3076f234_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_image
    ADD CONSTRAINT content_library_imag_created_by_id_3076f234_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_imageslice content_library_imag_created_by_id_74a09375_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_imageslice
    ADD CONSTRAINT content_library_imag_created_by_id_74a09375_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_imageslice content_library_imag_image_id_35414fbc_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_imageslice
    ADD CONSTRAINT content_library_imag_image_id_35414fbc_fk_content_l FOREIGN KEY (image_id) REFERENCES public.content_library_image(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_imageslice content_library_imag_image_layout_id_d5834bdc_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_imageslice
    ADD CONSTRAINT content_library_imag_image_layout_id_d5834bdc_fk_content_l FOREIGN KEY (image_layout_id) REFERENCES public.content_library_imagelayout(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_imageslice content_library_imag_link_id_ef02c7c5_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_imageslice
    ADD CONSTRAINT content_library_imag_link_id_ef02c7c5_fk_content_l FOREIGN KEY (link_id) REFERENCES public.content_library_link(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_imageslice content_library_imag_updated_by_id_04b84d6b_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_imageslice
    ADD CONSTRAINT content_library_imag_updated_by_id_04b84d6b_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_image content_library_imag_updated_by_id_560e3bbe_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_image
    ADD CONSTRAINT content_library_imag_updated_by_id_560e3bbe_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_imagelayout content_library_imag_updated_by_id_dbc9cc7d_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_imagelayout
    ADD CONSTRAINT content_library_imag_updated_by_id_dbc9cc7d_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_inboxpreview content_library_inbo_created_by_id_93940b03_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_inboxpreview
    ADD CONSTRAINT content_library_inbo_created_by_id_93940b03_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_inboxpreview content_library_inbo_creatives_variant_id_d5dc162f_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_inboxpreview
    ADD CONSTRAINT content_library_inbo_creatives_variant_id_d5dc162f_fk_content_l FOREIGN KEY (creatives_variant_id) REFERENCES public.content_library_eligiblecreativesvariant(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_inboxpreview content_library_inbo_discount_offer_dynam_4a48ca28_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_inboxpreview
    ADD CONSTRAINT content_library_inbo_discount_offer_dynam_4a48ca28_fk_content_l FOREIGN KEY (discount_offer_dynamic_id) REFERENCES public.content_library_dynamicsectionvariant(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_inboxpreview content_library_inbo_event_audience_id_5a78840b_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_inboxpreview
    ADD CONSTRAINT content_library_inbo_event_audience_id_5a78840b_fk_content_l FOREIGN KEY (event_audience_id) REFERENCES public.content_library_eventaudience(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_inboxpreview content_library_inbo_preheader_dynamic_id_ddd450ba_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_inboxpreview
    ADD CONSTRAINT content_library_inbo_preheader_dynamic_id_ddd450ba_fk_content_l FOREIGN KEY (preheader_dynamic_id) REFERENCES public.content_library_dynamicsectionvariant(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_inboxpreview content_library_inbo_preheader_link_stati_9b7cfc92_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_inboxpreview
    ADD CONSTRAINT content_library_inbo_preheader_link_stati_9b7cfc92_fk_content_l FOREIGN KEY (preheader_link_static_id) REFERENCES public.content_library_link(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_inboxpreview content_library_inbo_promotion_card_dynam_c279904d_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_inboxpreview
    ADD CONSTRAINT content_library_inbo_promotion_card_dynam_c279904d_fk_content_l FOREIGN KEY (promotion_card_dynamic_id) REFERENCES public.content_library_dynamicsectionvariant(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_inboxpreview content_library_inbo_subject_line_dynamic_dc9982bb_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_inboxpreview
    ADD CONSTRAINT content_library_inbo_subject_line_dynamic_dc9982bb_fk_content_l FOREIGN KEY (subject_line_dynamic_id) REFERENCES public.content_library_dynamicsectionvariant(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_inboxpreview content_library_inbo_subject_line_prefix__88f002db_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_inboxpreview
    ADD CONSTRAINT content_library_inbo_subject_line_prefix__88f002db_fk_content_l FOREIGN KEY (subject_line_prefix_dynamic_id) REFERENCES public.content_library_dynamicsectionvariant(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_inboxpreview content_library_inbo_subject_line_suffix__e69808f6_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_inboxpreview
    ADD CONSTRAINT content_library_inbo_subject_line_suffix__e69808f6_fk_content_l FOREIGN KEY (subject_line_suffix_dynamic_id) REFERENCES public.content_library_dynamicsectionvariant(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_inboxpreview content_library_inbo_updated_by_id_201ff340_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_inboxpreview
    ADD CONSTRAINT content_library_inbo_updated_by_id_201ff340_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_invitation content_library_invi_client_id_c4bbbbc2_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_invitation
    ADD CONSTRAINT content_library_invi_client_id_c4bbbbc2_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_invitation content_library_invi_inviter_id_fcf23131_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_invitation
    ADD CONSTRAINT content_library_invi_inviter_id_fcf23131_fk_content_l FOREIGN KEY (inviter_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_layout content_library_layo_client_id_7f5058fd_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_layout
    ADD CONSTRAINT content_library_layo_client_id_7f5058fd_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_layout content_library_layo_created_by_id_09cdda77_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_layout
    ADD CONSTRAINT content_library_layo_created_by_id_09cdda77_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_layout content_library_layo_updated_by_id_999b7ea1_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_layout
    ADD CONSTRAINT content_library_layo_updated_by_id_999b7ea1_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_linkcategory content_library_link_client_id_36425da4_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_linkcategory
    ADD CONSTRAINT content_library_link_client_id_36425da4_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_linkgroup content_library_link_client_id_4e3e533f_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_linkgroup
    ADD CONSTRAINT content_library_link_client_id_4e3e533f_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_link content_library_link_link_group_id_6f58549e_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_link
    ADD CONSTRAINT content_library_link_link_group_id_6f58549e_fk_content_l FOREIGN KEY (link_group_id) REFERENCES public.content_library_linkgroup(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_movableinkcreative content_library_mova_creative_id_7f8ab708_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_movableinkcreative
    ADD CONSTRAINT content_library_mova_creative_id_7f8ab708_fk_content_l FOREIGN KEY (creative_id) REFERENCES public.content_library_creative(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_movableinkintegration content_library_mova_user_id_964cdce8_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_movableinkintegration
    ADD CONSTRAINT content_library_mova_user_id_964cdce8_fk_content_l FOREIGN KEY (user_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_neweligiblecreative content_library_newe_configured_by_id_3de9b983_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_neweligiblecreative
    ADD CONSTRAINT content_library_newe_configured_by_id_3de9b983_fk_content_l FOREIGN KEY (configured_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_neweligiblecreative content_library_newe_creative_id_6ab6b295_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_neweligiblecreative
    ADD CONSTRAINT content_library_newe_creative_id_6ab6b295_fk_content_l FOREIGN KEY (creative_id) REFERENCES public.content_library_creative(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_neweligiblecreative content_library_newe_section_variant_id_c9a16766_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_neweligiblecreative
    ADD CONSTRAINT content_library_newe_section_variant_id_c9a16766_fk_content_l FOREIGN KEY (section_variant_id) REFERENCES public.content_library_dynamicsectionvariant(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_link content_library_newl_client_id_070189e4_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_link
    ADD CONSTRAINT content_library_newl_client_id_070189e4_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_link content_library_newl_created_by_id_f1f1bb05_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_link
    ADD CONSTRAINT content_library_newl_created_by_id_f1f1bb05_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_link content_library_newl_updated_by_id_c271a717_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_link
    ADD CONSTRAINT content_library_newl_updated_by_id_c271a717_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_neworacleresponsysclientconfig content_library_newo_client_id_29d558c3_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_neworacleresponsysclientconfig
    ADD CONSTRAINT content_library_newo_client_id_29d558c3_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_neworacleresponsysclientconfig content_library_newo_created_by_id_d569b7e4_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_neworacleresponsysclientconfig
    ADD CONSTRAINT content_library_newo_created_by_id_d569b7e4_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_neworacleresponsysclientconfig content_library_newo_profile_list_id_4b8cd1fa_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_neworacleresponsysclientconfig
    ADD CONSTRAINT content_library_newo_profile_list_id_4b8cd1fa_fk_content_l FOREIGN KEY (profile_list_id) REFERENCES public.content_library_oracleresponsyslist(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_neworacleresponsysclientconfig content_library_newo_updated_by_id_40932b71_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_neworacleresponsysclientconfig
    ADD CONSTRAINT content_library_newo_updated_by_id_40932b71_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_senddatetime content_library_news_send_time_personaliz_799fc884_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_senddatetime
    ADD CONSTRAINT content_library_news_send_time_personaliz_799fc884_fk_content_l FOREIGN KEY (send_time_personalization_variant_id) REFERENCES public.content_library_sendtimepersonalizationvariant(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_offer content_library_offe_client_id_5aa6684c_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_offer
    ADD CONSTRAINT content_library_offe_client_id_5aa6684c_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_offer content_library_offe_content_type_id_c1e76fc5_fk_django_co; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_offer
    ADD CONSTRAINT content_library_offe_content_type_id_c1e76fc5_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_offer content_library_offe_created_by_id_6a898c00_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_offer
    ADD CONSTRAINT content_library_offe_created_by_id_6a898c00_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_offer content_library_offe_updated_by_id_02884484_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_offer
    ADD CONSTRAINT content_library_offe_updated_by_id_02884484_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsysclientconfig content_library_orac_additional_pets_even_d5a65cf8_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsysclientconfig
    ADD CONSTRAINT content_library_orac_additional_pets_even_d5a65cf8_fk_content_l FOREIGN KEY (additional_pets_event_attribute_id) REFERENCES public.content_library_eventattribute(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsyscampaignvariablechoice content_library_orac_campaign_variable_id_0fbf4cbf_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyscampaignvariablechoice
    ADD CONSTRAINT content_library_orac_campaign_variable_id_0fbf4cbf_fk_content_l FOREIGN KEY (campaign_variable_id) REFERENCES public.content_library_oracleresponsyscampaignvariable(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsyslinkmetadata content_library_orac_category_id_f290dc64_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyslinkmetadata
    ADD CONSTRAINT content_library_orac_category_id_f290dc64_fk_content_l FOREIGN KEY (category_id) REFERENCES public.content_library_linkcategory(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsysmarketingprogram content_library_orac_client_id_05446fec_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsysmarketingprogram
    ADD CONSTRAINT content_library_orac_client_id_05446fec_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsyslist content_library_orac_client_id_054d564c_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyslist
    ADD CONSTRAINT content_library_orac_client_id_054d564c_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsysadditionaldatasource content_library_orac_client_id_0c70d09d_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsysadditionaldatasource
    ADD CONSTRAINT content_library_orac_client_id_0c70d09d_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsyssenderprofile content_library_orac_client_id_36ef0422_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyssenderprofile
    ADD CONSTRAINT content_library_orac_client_id_36ef0422_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsysmarketingstrategy content_library_orac_client_id_aa4fcf37_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsysmarketingstrategy
    ADD CONSTRAINT content_library_orac_client_id_aa4fcf37_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsyscampaignvariable content_library_orac_client_id_d260876d_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyscampaignvariable
    ADD CONSTRAINT content_library_orac_client_id_d260876d_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsyssuppression content_library_orac_client_id_f6b005e4_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyssuppression
    ADD CONSTRAINT content_library_orac_client_id_f6b005e4_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsysstaticcontentblockdocument content_library_orac_content_block_id_2c2fe159_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsysstaticcontentblockdocument
    ADD CONSTRAINT content_library_orac_content_block_id_2c2fe159_fk_content_l FOREIGN KEY (content_block_id) REFERENCES public.content_library_contentblock(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsyscreativecontentblockdocument content_library_orac_content_block_id_60ef1de3_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyscreativecontentblockdocument
    ADD CONSTRAINT content_library_orac_content_block_id_60ef1de3_fk_content_l FOREIGN KEY (content_block_id) REFERENCES public.content_library_contentblock(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsyscreativedocument content_library_orac_contentblock_id_af01d293_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyscreativedocument
    ADD CONSTRAINT content_library_orac_contentblock_id_af01d293_fk_content_l FOREIGN KEY (contentblock_id) REFERENCES public.content_library_contentblock(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsysadditionaldatasource content_library_orac_created_by_id_05679091_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsysadditionaldatasource
    ADD CONSTRAINT content_library_orac_created_by_id_05679091_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsyscreativecontentblockdocument content_library_orac_created_by_id_3627512e_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyscreativecontentblockdocument
    ADD CONSTRAINT content_library_orac_created_by_id_3627512e_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsyslaunch content_library_orac_created_by_id_3d32e582_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyslaunch
    ADD CONSTRAINT content_library_orac_created_by_id_3d32e582_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsyscreativedocument content_library_orac_created_by_id_4964b3ec_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyscreativedocument
    ADD CONSTRAINT content_library_orac_created_by_id_4964b3ec_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsyssenderprofile content_library_orac_created_by_id_67fb5b70_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyssenderprofile
    ADD CONSTRAINT content_library_orac_created_by_id_67fb5b70_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsyslist content_library_orac_created_by_id_7140d345_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyslist
    ADD CONSTRAINT content_library_orac_created_by_id_7140d345_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsysclientconfig content_library_orac_created_by_id_758bf0ae_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsysclientconfig
    ADD CONSTRAINT content_library_orac_created_by_id_758bf0ae_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsysstaticcontentblockdocument content_library_orac_created_by_id_7821702c_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsysstaticcontentblockdocument
    ADD CONSTRAINT content_library_orac_created_by_id_7821702c_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsyscampaignvariable content_library_orac_created_by_id_9d280e1b_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyscampaignvariable
    ADD CONSTRAINT content_library_orac_created_by_id_9d280e1b_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsyssuppression content_library_orac_created_by_id_a1a4183c_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyssuppression
    ADD CONSTRAINT content_library_orac_created_by_id_a1a4183c_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsyscreativediscountofferdocument content_library_orac_created_by_id_c14df83d_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyscreativediscountofferdocument
    ADD CONSTRAINT content_library_orac_created_by_id_c14df83d_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsysmarketingprogram content_library_orac_created_by_id_cf7ae778_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsysmarketingprogram
    ADD CONSTRAINT content_library_orac_created_by_id_cf7ae778_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsysmarketingstrategy content_library_orac_created_by_id_e0705f0f_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsysmarketingstrategy
    ADD CONSTRAINT content_library_orac_created_by_id_e0705f0f_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsyscreativecontentblockdocument content_library_orac_creative_id_6ee02c3f_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyscreativecontentblockdocument
    ADD CONSTRAINT content_library_orac_creative_id_6ee02c3f_fk_content_l FOREIGN KEY (creative_id) REFERENCES public.content_library_creative(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsyscreativedocument content_library_orac_creative_id_e518e9d3_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyscreativedocument
    ADD CONSTRAINT content_library_orac_creative_id_e518e9d3_fk_content_l FOREIGN KEY (creative_id) REFERENCES public.content_library_creative(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsyscreativediscountofferdocument content_library_orac_document_id_8067c9c2_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyscreativediscountofferdocument
    ADD CONSTRAINT content_library_orac_document_id_8067c9c2_fk_content_l FOREIGN KEY (document_id) REFERENCES public.content_library_oracleresponsyscreativedocument(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsys content_library_orac_emailserviceprovider_794883c4_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsys
    ADD CONSTRAINT content_library_orac_emailserviceprovider_794883c4_fk_content_l FOREIGN KEY (emailserviceprovider_ptr_id) REFERENCES public.content_library_emailserviceprovider(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsysclientconfig content_library_orac_esp_id_ce172e93_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsysclientconfig
    ADD CONSTRAINT content_library_orac_esp_id_ce172e93_fk_content_l FOREIGN KEY (esp_id) REFERENCES public.content_library_emailserviceprovider(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsyslaunch content_library_orac_event_id_2f4769b5_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyslaunch
    ADD CONSTRAINT content_library_orac_event_id_2f4769b5_fk_content_l FOREIGN KEY (event_id) REFERENCES public.content_library_event(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsysclientconfig content_library_orac_external_campaign_co_0b7c27a4_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsysclientconfig
    ADD CONSTRAINT content_library_orac_external_campaign_co_0b7c27a4_fk_content_l FOREIGN KEY (external_campaign_code_event_attribute_id) REFERENCES public.content_library_eventattribute(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsyslinkmetadata content_library_orac_link_id_5fe4cf2b_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyslinkmetadata
    ADD CONSTRAINT content_library_orac_link_id_5fe4cf2b_fk_content_l FOREIGN KEY (link_id) REFERENCES public.content_library_link(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsyslinkmetadata content_library_orac_oracle_responsys_id_12b58bba_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyslinkmetadata
    ADD CONSTRAINT content_library_orac_oracle_responsys_id_12b58bba_fk_content_l FOREIGN KEY (oracle_responsys_id) REFERENCES public.content_library_oracleresponsys(emailserviceprovider_ptr_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsyscreativediscountofferdocument content_library_orac_promotion_redemption_126ead3d_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyscreativediscountofferdocument
    ADD CONSTRAINT content_library_orac_promotion_redemption_126ead3d_fk_content_l FOREIGN KEY (promotion_redemption_id) REFERENCES public.content_library_promotionredemption(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsysmarketingstrategy content_library_orac_updated_by_id_1db86838_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsysmarketingstrategy
    ADD CONSTRAINT content_library_orac_updated_by_id_1db86838_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsyslist content_library_orac_updated_by_id_447cbc5b_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyslist
    ADD CONSTRAINT content_library_orac_updated_by_id_447cbc5b_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsysclientconfig content_library_orac_updated_by_id_5b7a0dc1_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsysclientconfig
    ADD CONSTRAINT content_library_orac_updated_by_id_5b7a0dc1_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsyscreativedocument content_library_orac_updated_by_id_5bee9e44_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyscreativedocument
    ADD CONSTRAINT content_library_orac_updated_by_id_5bee9e44_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsyssenderprofile content_library_orac_updated_by_id_75de24b1_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyssenderprofile
    ADD CONSTRAINT content_library_orac_updated_by_id_75de24b1_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsyssuppression content_library_orac_updated_by_id_88e72c38_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyssuppression
    ADD CONSTRAINT content_library_orac_updated_by_id_88e72c38_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsyslaunch content_library_orac_updated_by_id_8e9bbe5b_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyslaunch
    ADD CONSTRAINT content_library_orac_updated_by_id_8e9bbe5b_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsyscreativecontentblockdocument content_library_orac_updated_by_id_aca0610c_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyscreativecontentblockdocument
    ADD CONSTRAINT content_library_orac_updated_by_id_aca0610c_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsyscreativediscountofferdocument content_library_orac_updated_by_id_ad0c77e5_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyscreativediscountofferdocument
    ADD CONSTRAINT content_library_orac_updated_by_id_ad0c77e5_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsyscampaignvariable content_library_orac_updated_by_id_d56fade4_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsyscampaignvariable
    ADD CONSTRAINT content_library_orac_updated_by_id_d56fade4_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsysadditionaldatasource content_library_orac_updated_by_id_d74dcfe2_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsysadditionaldatasource
    ADD CONSTRAINT content_library_orac_updated_by_id_d74dcfe2_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsysmarketingprogram content_library_orac_updated_by_id_f4783b47_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsysmarketingprogram
    ADD CONSTRAINT content_library_orac_updated_by_id_f4783b47_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_oracleresponsysstaticcontentblockdocument content_library_orac_updated_by_id_f9fa3eb6_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_oracleresponsysstaticcontentblockdocument
    ADD CONSTRAINT content_library_orac_updated_by_id_f9fa3eb6_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_persadocampaign content_library_pers_client_id_32776b97_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_persadocampaign
    ADD CONSTRAINT content_library_pers_client_id_32776b97_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_persadocampaign content_library_pers_created_by_id_1283c4f0_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_persadocampaign
    ADD CONSTRAINT content_library_pers_created_by_id_1283c4f0_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_persadocampaign content_library_pers_updated_by_id_613be960_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_persadocampaign
    ADD CONSTRAINT content_library_pers_updated_by_id_613be960_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_productfield content_library_prod_client_id_d92969e7_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_productfield
    ADD CONSTRAINT content_library_prod_client_id_d92969e7_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_productvalue content_library_prod_created_by_id_205d365e_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_productvalue
    ADD CONSTRAINT content_library_prod_created_by_id_205d365e_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_productcollection content_library_prod_created_by_id_2c4c4cda_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_productcollection
    ADD CONSTRAINT content_library_prod_created_by_id_2c4c4cda_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_productfield content_library_prod_created_by_id_4fdc2892_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_productfield
    ADD CONSTRAINT content_library_prod_created_by_id_4fdc2892_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_productvalue content_library_prod_product_field_id_683581fe_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_productvalue
    ADD CONSTRAINT content_library_prod_product_field_id_683581fe_fk_content_l FOREIGN KEY (product_field_id) REFERENCES public.content_library_productfield(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_productcollection_product_values content_library_prod_productcollection_id_4720bba8_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_productcollection_product_values
    ADD CONSTRAINT content_library_prod_productcollection_id_4720bba8_fk_content_l FOREIGN KEY (productcollection_id) REFERENCES public.content_library_productcollection(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_productcollection_product_values content_library_prod_productvalue_id_7427607c_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_productcollection_product_values
    ADD CONSTRAINT content_library_prod_productvalue_id_7427607c_fk_content_l FOREIGN KEY (productvalue_id) REFERENCES public.content_library_productvalue(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_productfield content_library_prod_updated_by_id_3308a3d4_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_productfield
    ADD CONSTRAINT content_library_prod_updated_by_id_3308a3d4_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_productcollection content_library_prod_updated_by_id_85682f17_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_productcollection
    ADD CONSTRAINT content_library_prod_updated_by_id_85682f17_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_productvalue content_library_prod_updated_by_id_9d96e51c_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_productvalue
    ADD CONSTRAINT content_library_prod_updated_by_id_9d96e51c_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_prohibitedcreativeproductcollection content_library_proh_created_by_id_370dc116_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_prohibitedcreativeproductcollection
    ADD CONSTRAINT content_library_proh_created_by_id_370dc116_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_prohibitedcreativetag content_library_proh_created_by_id_d23cc545_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_prohibitedcreativetag
    ADD CONSTRAINT content_library_proh_created_by_id_d23cc545_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_prohibitedcreativetag content_library_proh_creative_id_5e30bba8_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_prohibitedcreativetag
    ADD CONSTRAINT content_library_proh_creative_id_5e30bba8_fk_content_l FOREIGN KEY (creative_id) REFERENCES public.content_library_creative(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_prohibitedcreativeproductcollection content_library_proh_creative_id_9ca7812b_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_prohibitedcreativeproductcollection
    ADD CONSTRAINT content_library_proh_creative_id_9ca7812b_fk_content_l FOREIGN KEY (creative_id) REFERENCES public.content_library_creative(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_prohibitedcreativeproductcollection content_library_proh_productcollection_id_1ce02a0c_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_prohibitedcreativeproductcollection
    ADD CONSTRAINT content_library_proh_productcollection_id_1ce02a0c_fk_content_l FOREIGN KEY (productcollection_id) REFERENCES public.content_library_productcollection(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_prohibitedcreativetag content_library_proh_tag_id_73c6d633_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_prohibitedcreativetag
    ADD CONSTRAINT content_library_proh_tag_id_73c6d633_fk_content_l FOREIGN KEY (tag_id) REFERENCES public.content_library_tag(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_prohibitedcreativetag content_library_proh_updated_by_id_99e690dc_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_prohibitedcreativetag
    ADD CONSTRAINT content_library_proh_updated_by_id_99e690dc_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_prohibitedcreativeproductcollection content_library_proh_updated_by_id_b38c8a67_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_prohibitedcreativeproductcollection
    ADD CONSTRAINT content_library_proh_updated_by_id_b38c8a67_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_promotion content_library_prom_client_id_236e610b_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_promotion
    ADD CONSTRAINT content_library_prom_client_id_236e610b_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_promotion content_library_prom_created_by_id_2e45378c_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_promotion
    ADD CONSTRAINT content_library_prom_created_by_id_2e45378c_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_promotionoffer content_library_prom_offer_id_3219499f_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_promotionoffer
    ADD CONSTRAINT content_library_prom_offer_id_3219499f_fk_content_l FOREIGN KEY (offer_id) REFERENCES public.content_library_offer(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_promotionredemption content_library_prom_promotion_id_5781df86_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_promotionredemption
    ADD CONSTRAINT content_library_prom_promotion_id_5781df86_fk_content_l FOREIGN KEY (promotion_id) REFERENCES public.content_library_promotion(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_promotionoffer content_library_prom_promotion_id_87815beb_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_promotionoffer
    ADD CONSTRAINT content_library_prom_promotion_id_87815beb_fk_content_l FOREIGN KEY (promotion_id) REFERENCES public.content_library_promotion(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_promotion content_library_prom_updated_by_id_caea0134_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_promotion
    ADD CONSTRAINT content_library_prom_updated_by_id_caea0134_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_proxycontrolexperiment content_library_prox_baseexperiment_ptr_i_190e21d6_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_proxycontrolexperiment
    ADD CONSTRAINT content_library_prox_baseexperiment_ptr_i_190e21d6_fk_content_l FOREIGN KEY (baseexperiment_ptr_id) REFERENCES public.content_library_baseexperiment(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_proxycontroltreatment content_library_prox_basetreatment_ptr_id_cdaa2ff9_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_proxycontroltreatment
    ADD CONSTRAINT content_library_prox_basetreatment_ptr_id_cdaa2ff9_fk_content_l FOREIGN KEY (basetreatment_ptr_id) REFERENCES public.content_library_basetreatment(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_proxycontrolvariant content_library_prox_created_by_id_3d265952_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_proxycontrolvariant
    ADD CONSTRAINT content_library_prox_created_by_id_3d265952_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_proxycontrolvariant content_library_prox_event_id_8c855aa0_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_proxycontrolvariant
    ADD CONSTRAINT content_library_prox_event_id_8c855aa0_fk_content_l FOREIGN KEY (event_id) REFERENCES public.content_library_event(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_proxycontroltreatment content_library_prox_experiment_id_0e6ec5ee_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_proxycontroltreatment
    ADD CONSTRAINT content_library_prox_experiment_id_0e6ec5ee_fk_content_l FOREIGN KEY (experiment_id) REFERENCES public.content_library_proxycontrolexperiment(baseexperiment_ptr_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_proxycontrolvariant content_library_prox_treatment_id_95d14b42_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_proxycontrolvariant
    ADD CONSTRAINT content_library_prox_treatment_id_95d14b42_fk_content_l FOREIGN KEY (treatment_id) REFERENCES public.content_library_proxycontroltreatment(basetreatment_ptr_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_proxycontrolvariant content_library_prox_updated_by_id_b46b8b90_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_proxycontrolvariant
    ADD CONSTRAINT content_library_prox_updated_by_id_b46b8b90_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_quantitydiscount content_library_quan_created_by_id_8a3ef5c0_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_quantitydiscount
    ADD CONSTRAINT content_library_quan_created_by_id_8a3ef5c0_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_quantitydiscount content_library_quan_updated_by_id_e4d275fc_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_quantitydiscount
    ADD CONSTRAINT content_library_quan_updated_by_id_e4d275fc_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_querystringparameter content_library_quer_client_id_c36de163_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_querystringparameter
    ADD CONSTRAINT content_library_quer_client_id_c36de163_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_querystringparameter content_library_quer_created_by_id_cb89cf61_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_querystringparameter
    ADD CONSTRAINT content_library_quer_created_by_id_cb89cf61_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_querystringparameter content_library_quer_updated_by_id_8e362a06_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_querystringparameter
    ADD CONSTRAINT content_library_quer_updated_by_id_8e362a06_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_recommendationrun content_library_reco_client_id_d6a21a93_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_recommendationrun
    ADD CONSTRAINT content_library_reco_client_id_d6a21a93_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_contentpersonalizationmodel content_library_reco_created_by_id_711314d8_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentpersonalizationmodel
    ADD CONSTRAINT content_library_reco_created_by_id_711314d8_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_recommendationrun_events content_library_reco_event_id_8ddefaf2_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_recommendationrun_events
    ADD CONSTRAINT content_library_reco_event_id_8ddefaf2_fk_content_l FOREIGN KEY (event_id) REFERENCES public.content_library_event(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_recommendationrunlog content_library_reco_event_id_c85a4be2_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_recommendationrunlog
    ADD CONSTRAINT content_library_reco_event_id_c85a4be2_fk_content_l FOREIGN KEY (event_id) REFERENCES public.content_library_event(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_recommendationrunlog content_library_reco_recommendation_run_i_eb3e0a47_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_recommendationrunlog
    ADD CONSTRAINT content_library_reco_recommendation_run_i_eb3e0a47_fk_content_l FOREIGN KEY (recommendation_run_id) REFERENCES public.content_library_recommendationrun(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_recommendationrun_events content_library_reco_recommendationrun_id_57048bca_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_recommendationrun_events
    ADD CONSTRAINT content_library_reco_recommendationrun_id_57048bca_fk_content_l FOREIGN KEY (recommendationrun_id) REFERENCES public.content_library_recommendationrun(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_contentpersonalizationmodel content_library_reco_updated_by_id_236b84d1_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_contentpersonalizationmodel
    ADD CONSTRAINT content_library_reco_updated_by_id_236b84d1_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_renderedcreative content_library_rend_content_block_id_abd8b635_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_renderedcreative
    ADD CONSTRAINT content_library_rend_content_block_id_abd8b635_fk_content_l FOREIGN KEY (content_block_id) REFERENCES public.content_library_contentblock(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_renderedcreative content_library_rend_creative_id_3afc0353_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_renderedcreative
    ADD CONSTRAINT content_library_rend_creative_id_3afc0353_fk_content_l FOREIGN KEY (creative_id) REFERENCES public.content_library_creative(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_rewardsmultiplier content_library_rewa_created_by_id_5fe69c8f_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_rewardsmultiplier
    ADD CONSTRAINT content_library_rewa_created_by_id_5fe69c8f_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_rewardsmultiplier content_library_rewa_updated_by_id_70a6a62d_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_rewardsmultiplier
    ADD CONSTRAINT content_library_rewa_updated_by_id_70a6a62d_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_salesforcemarketingcloudintegration content_library_sale_client_id_0ba374c3_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudintegration
    ADD CONSTRAINT content_library_sale_client_id_0ba374c3_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_salesforcemarketingcloudpublicationlist content_library_sale_client_id_13f69239_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudpublicationlist
    ADD CONSTRAINT content_library_sale_client_id_13f69239_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_salesforcemarketingcloudmessagedeliveryconfig content_library_sale_client_id_16972eb6_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudmessagedeliveryconfig
    ADD CONSTRAINT content_library_sale_client_id_16972eb6_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_salesforcemarketingcloudsenderprofile content_library_sale_client_id_51d8d6a6_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudsenderprofile
    ADD CONSTRAINT content_library_sale_client_id_51d8d6a6_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_salesforcemarketingcloudsuppressiondataexte91a1 content_library_sale_client_id_ae30eb16_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudsuppressiondataexte91a1
    ADD CONSTRAINT content_library_sale_client_id_ae30eb16_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_salesforcemarketingcloudstaticcontentblockda7ea content_library_sale_content_block_id_32694796_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudstaticcontentblockda7ea
    ADD CONSTRAINT content_library_sale_content_block_id_32694796_fk_content_l FOREIGN KEY (content_block_id) REFERENCES public.content_library_contentblock(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_salesforcemarketingcloudcreativecontentblocaf9f content_library_sale_content_block_id_74ab0131_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudcreativecontentblocaf9f
    ADD CONSTRAINT content_library_sale_content_block_id_74ab0131_fk_content_l FOREIGN KEY (content_block_id) REFERENCES public.content_library_contentblock(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_salesforcemarketingcloudcreativedocument content_library_sale_contentblock_id_6ebb3562_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudcreativedocument
    ADD CONSTRAINT content_library_sale_contentblock_id_6ebb3562_fk_content_l FOREIGN KEY (contentblock_id) REFERENCES public.content_library_contentblock(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_salesforcemarketingcloudcreativediscountoff3b11 content_library_sale_created_by_id_2503522b_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudcreativediscountoff3b11
    ADD CONSTRAINT content_library_sale_created_by_id_2503522b_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_salesforcemarketingcloudsend content_library_sale_created_by_id_2c67b657_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudsend
    ADD CONSTRAINT content_library_sale_created_by_id_2c67b657_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_salesforcemarketingcloudstaticcontentblockda7ea content_library_sale_created_by_id_329755dd_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudstaticcontentblockda7ea
    ADD CONSTRAINT content_library_sale_created_by_id_329755dd_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_salesforcemarketingcloudcreativedocument content_library_sale_created_by_id_3e07ab26_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudcreativedocument
    ADD CONSTRAINT content_library_sale_created_by_id_3e07ab26_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_salesforcemarketingcloudcreativecontentblocaf9f content_library_sale_created_by_id_d37f1787_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudcreativecontentblocaf9f
    ADD CONSTRAINT content_library_sale_created_by_id_d37f1787_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_salesforcemarketingcloudcreativecontentblocaf9f content_library_sale_creative_id_50105783_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudcreativecontentblocaf9f
    ADD CONSTRAINT content_library_sale_creative_id_50105783_fk_content_l FOREIGN KEY (creative_id) REFERENCES public.content_library_creative(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_salesforcemarketingcloudcreativedocument content_library_sale_creative_id_6ea18603_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudcreativedocument
    ADD CONSTRAINT content_library_sale_creative_id_6ea18603_fk_content_l FOREIGN KEY (creative_id) REFERENCES public.content_library_creative(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_salesforcemarketingcloudcreativediscountoff3b11 content_library_sale_document_id_66ecbb62_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudcreativediscountoff3b11
    ADD CONSTRAINT content_library_sale_document_id_66ecbb62_fk_content_l FOREIGN KEY (document_id) REFERENCES public.content_library_salesforcemarketingcloudcreativedocument(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_salesforcemarketingcloud content_library_sale_emailserviceprovider_f73dbaa2_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloud
    ADD CONSTRAINT content_library_sale_emailserviceprovider_f73dbaa2_fk_content_l FOREIGN KEY (emailserviceprovider_ptr_id) REFERENCES public.content_library_emailserviceprovider(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_salesforcemarketingcloudsend content_library_sale_event_id_df063b40_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudsend
    ADD CONSTRAINT content_library_sale_event_id_df063b40_fk_content_l FOREIGN KEY (event_id) REFERENCES public.content_library_event(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_salesforcemarketingcloudlinkmetadata content_library_sale_link_id_d81e268b_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudlinkmetadata
    ADD CONSTRAINT content_library_sale_link_id_d81e268b_fk_content_l FOREIGN KEY (link_id) REFERENCES public.content_library_link(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_salesforcemarketingcloudcreativediscountoff3b11 content_library_sale_promotion_redemption_3394d714_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudcreativediscountoff3b11
    ADD CONSTRAINT content_library_sale_promotion_redemption_3394d714_fk_content_l FOREIGN KEY (promotion_redemption_id) REFERENCES public.content_library_promotionredemption(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_salesforcemarketingcloudlinkmetadata content_library_sale_salesforce_marketing_c6bb8f58_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudlinkmetadata
    ADD CONSTRAINT content_library_sale_salesforce_marketing_c6bb8f58_fk_content_l FOREIGN KEY (salesforce_marketing_cloud_id) REFERENCES public.content_library_salesforcemarketingcloud(emailserviceprovider_ptr_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_salesforcemarketingcloudstaticcontentblockda7ea content_library_sale_updated_by_id_65115418_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudstaticcontentblockda7ea
    ADD CONSTRAINT content_library_sale_updated_by_id_65115418_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_salesforcemarketingcloudsend content_library_sale_updated_by_id_66a73543_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudsend
    ADD CONSTRAINT content_library_sale_updated_by_id_66a73543_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_salesforcemarketingcloudcreativecontentblocaf9f content_library_sale_updated_by_id_6b71a726_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudcreativecontentblocaf9f
    ADD CONSTRAINT content_library_sale_updated_by_id_6b71a726_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_salesforcemarketingcloudcreativediscountoff3b11 content_library_sale_updated_by_id_7a20f932_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudcreativediscountoff3b11
    ADD CONSTRAINT content_library_sale_updated_by_id_7a20f932_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_salesforcemarketingcloudcreativedocument content_library_sale_updated_by_id_fbdff8da_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudcreativedocument
    ADD CONSTRAINT content_library_sale_updated_by_id_fbdff8da_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_salesforcemarketingcloudintegration content_library_sale_user_id_b2d6092b_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_salesforcemarketingcloudintegration
    ADD CONSTRAINT content_library_sale_user_id_b2d6092b_fk_content_l FOREIGN KEY (user_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_section content_library_sect_contentblock_id_8bf94c1c_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_section
    ADD CONSTRAINT content_library_sect_contentblock_id_8bf94c1c_fk_content_l FOREIGN KEY (contentblock_id) REFERENCES public.content_library_contentblock(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_section content_library_sect_event_id_2c528bae_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_section
    ADD CONSTRAINT content_library_sect_event_id_2c528bae_fk_content_l FOREIGN KEY (event_id) REFERENCES public.content_library_event(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_section content_library_sect_template_variant_id_0738c336_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_section
    ADD CONSTRAINT content_library_sect_template_variant_id_0738c336_fk_content_l FOREIGN KEY (template_variant_id) REFERENCES public.content_library_templatevariant(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_senddatetimeexperiment content_library_send_baseexperiment_ptr_i_2f568e52_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_senddatetimeexperiment
    ADD CONSTRAINT content_library_send_baseexperiment_ptr_i_2f568e52_fk_content_l FOREIGN KEY (baseexperiment_ptr_id) REFERENCES public.content_library_baseexperiment(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_senddatetimetreatment content_library_send_basetreatment_ptr_id_36578650_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_senddatetimetreatment
    ADD CONSTRAINT content_library_send_basetreatment_ptr_id_36578650_fk_content_l FOREIGN KEY (basetreatment_ptr_id) REFERENCES public.content_library_basetreatment(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_sendtimepersonalizationvariant content_library_send_created_by_id_c22af839_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_sendtimepersonalizationvariant
    ADD CONSTRAINT content_library_send_created_by_id_c22af839_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_sendtimepersonalizationvariant content_library_send_event_id_e47c5144_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_sendtimepersonalizationvariant
    ADD CONSTRAINT content_library_send_event_id_e47c5144_fk_content_l FOREIGN KEY (event_id) REFERENCES public.content_library_event(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_senddatetimetreatment content_library_send_experiment_id_6c862b85_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_senddatetimetreatment
    ADD CONSTRAINT content_library_send_experiment_id_6c862b85_fk_content_l FOREIGN KEY (experiment_id) REFERENCES public.content_library_senddatetimeexperiment(baseexperiment_ptr_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_sendtimepersonalizationvariant content_library_send_treatment_id_452ee0e0_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_sendtimepersonalizationvariant
    ADD CONSTRAINT content_library_send_treatment_id_452ee0e0_fk_content_l FOREIGN KEY (treatment_id) REFERENCES public.content_library_senddatetimetreatment(basetreatment_ptr_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_sendtimepersonalizationvariant content_library_send_updated_by_id_a644ea58_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_sendtimepersonalizationvariant
    ADD CONSTRAINT content_library_send_updated_by_id_a644ea58_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_session content_library_sess_client_id_f98b5006_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_session
    ADD CONSTRAINT content_library_sess_client_id_f98b5006_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_slice content_library_slic_client_id_f8a2f90b_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_slice
    ADD CONSTRAINT content_library_slic_client_id_f8a2f90b_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_slice content_library_slic_created_by_id_57eeeae4_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_slice
    ADD CONSTRAINT content_library_slic_created_by_id_57eeeae4_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_slice content_library_slic_image_id_728c9c19_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_slice
    ADD CONSTRAINT content_library_slic_image_id_728c9c19_fk_content_l FOREIGN KEY (image_id) REFERENCES public.content_library_image(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_slice content_library_slic_layout_id_8fd5c6ce_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_slice
    ADD CONSTRAINT content_library_slic_layout_id_8fd5c6ce_fk_content_l FOREIGN KEY (layout_id) REFERENCES public.content_library_layout(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_slice content_library_slic_link_id_5a9859a9_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_slice
    ADD CONSTRAINT content_library_slic_link_id_5a9859a9_fk_content_l FOREIGN KEY (link_id) REFERENCES public.content_library_link(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_slice content_library_slic_updated_by_id_297a1753_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_slice
    ADD CONSTRAINT content_library_slic_updated_by_id_297a1753_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_staticaudiencemetadata content_library_stat_audience_id_bb71969f_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_staticaudiencemetadata
    ADD CONSTRAINT content_library_stat_audience_id_bb71969f_fk_content_l FOREIGN KEY (audience_id) REFERENCES public.content_library_audience(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_staticaudiencemetadata content_library_stat_created_by_id_fd9581a3_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_staticaudiencemetadata
    ADD CONSTRAINT content_library_stat_created_by_id_fd9581a3_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_staticaudiencemetadata content_library_stat_updated_by_id_9aa4d906_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_staticaudiencemetadata
    ADD CONSTRAINT content_library_stat_updated_by_id_9aa4d906_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_subjectline content_library_subj_created_by_id_f2aa13c4_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_subjectline
    ADD CONSTRAINT content_library_subj_created_by_id_f2aa13c4_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_subjectline content_library_subj_creative_id_7d3ce58d_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_subjectline
    ADD CONSTRAINT content_library_subj_creative_id_7d3ce58d_fk_content_l FOREIGN KEY (creative_id) REFERENCES public.content_library_creative(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_subjectline content_library_subj_updated_by_id_169e518d_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_subjectline
    ADD CONSTRAINT content_library_subj_updated_by_id_169e518d_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_tag content_library_tag_client_id_135476bd_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_tag
    ADD CONSTRAINT content_library_tag_client_id_135476bd_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_tag content_library_tag_created_by_id_cb1f66a9_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_tag
    ADD CONSTRAINT content_library_tag_created_by_id_cb1f66a9_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_tag content_library_tag_updated_by_id_95cfac41_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_tag
    ADD CONSTRAINT content_library_tag_updated_by_id_95cfac41_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_templateexperiment content_library_temp_baseexperiment_ptr_i_27c0e25b_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_templateexperiment
    ADD CONSTRAINT content_library_temp_baseexperiment_ptr_i_27c0e25b_fk_content_l FOREIGN KEY (baseexperiment_ptr_id) REFERENCES public.content_library_baseexperiment(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_templatetreatment content_library_temp_basetreatment_ptr_id_471842f2_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_templatetreatment
    ADD CONSTRAINT content_library_temp_basetreatment_ptr_id_471842f2_fk_content_l FOREIGN KEY (basetreatment_ptr_id) REFERENCES public.content_library_basetreatment(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_template content_library_temp_body_id_0e352379_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_template
    ADD CONSTRAINT content_library_temp_body_id_0e352379_fk_content_l FOREIGN KEY (body_id) REFERENCES public.content_library_htmlbundle(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_template content_library_temp_client_id_3919775d_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_template
    ADD CONSTRAINT content_library_temp_client_id_3919775d_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_templatetag content_library_temp_client_id_c65b3508_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_templatetag
    ADD CONSTRAINT content_library_temp_client_id_c65b3508_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_templatecontentblock content_library_temp_content_block_id_62fb840a_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_templatecontentblock
    ADD CONSTRAINT content_library_temp_content_block_id_62fb840a_fk_content_l FOREIGN KEY (content_block_id) REFERENCES public.content_library_contentblock(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_template content_library_temp_created_by_id_18c1f511_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_template
    ADD CONSTRAINT content_library_temp_created_by_id_18c1f511_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_templatetag content_library_temp_created_by_id_95d13a7b_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_templatetag
    ADD CONSTRAINT content_library_temp_created_by_id_95d13a7b_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_templatevariant content_library_temp_created_by_id_fc984f40_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_templatevariant
    ADD CONSTRAINT content_library_temp_created_by_id_fc984f40_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_templatevariant content_library_temp_event_id_e25d3bf9_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_templatevariant
    ADD CONSTRAINT content_library_temp_event_id_e25d3bf9_fk_content_l FOREIGN KEY (event_id) REFERENCES public.content_library_event(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_templatetreatment content_library_temp_experiment_id_6ea4a0dd_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_templatetreatment
    ADD CONSTRAINT content_library_temp_experiment_id_6ea4a0dd_fk_content_l FOREIGN KEY (experiment_id) REFERENCES public.content_library_templateexperiment(baseexperiment_ptr_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_templatecontentblock content_library_temp_template_id_c6525434_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_templatecontentblock
    ADD CONSTRAINT content_library_temp_template_id_c6525434_fk_content_l FOREIGN KEY (template_id) REFERENCES public.content_library_template(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_templatetagchoice content_library_temp_template_tag_id_360f66c1_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_templatetagchoice
    ADD CONSTRAINT content_library_temp_template_tag_id_360f66c1_fk_content_l FOREIGN KEY (template_tag_id) REFERENCES public.content_library_templatetag(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_templatevariant content_library_temp_treatment_id_38c77b4a_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_templatevariant
    ADD CONSTRAINT content_library_temp_treatment_id_38c77b4a_fk_content_l FOREIGN KEY (treatment_id) REFERENCES public.content_library_templatetreatment(basetreatment_ptr_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_templatetag content_library_temp_updated_by_id_64c4bb36_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_templatetag
    ADD CONSTRAINT content_library_temp_updated_by_id_64c4bb36_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_templatevariant content_library_temp_updated_by_id_b0cc528f_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_templatevariant
    ADD CONSTRAINT content_library_temp_updated_by_id_b0cc528f_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_template content_library_temp_updated_by_id_feb2421d_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_template
    ADD CONSTRAINT content_library_temp_updated_by_id_feb2421d_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_trackingparameter content_library_trac_client_id_af41118d_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_trackingparameter
    ADD CONSTRAINT content_library_trac_client_id_af41118d_fk_content_l FOREIGN KEY (client_id) REFERENCES public.content_library_client(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_trackingparameter content_library_trac_created_by_id_f6d91616_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_trackingparameter
    ADD CONSTRAINT content_library_trac_created_by_id_f6d91616_fk_content_l FOREIGN KEY (created_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_trackingparameterchoice content_library_trac_tracking_parameter_i_fcfca784_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_trackingparameterchoice
    ADD CONSTRAINT content_library_trac_tracking_parameter_i_fcfca784_fk_content_l FOREIGN KEY (tracking_parameter_id) REFERENCES public.content_library_trackingparameter(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_trackingparameter content_library_trac_updated_by_id_0bfed277_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_trackingparameter
    ADD CONSTRAINT content_library_trac_updated_by_id_0bfed277_fk_content_l FOREIGN KEY (updated_by_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_user_groups content_library_user_groups_group_id_60d2a399_fk_auth_group_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_user_groups
    ADD CONSTRAINT content_library_user_groups_group_id_60d2a399_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES public.auth_group(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_user_user_permissions content_library_user_permission_id_93c7b786_fk_auth_perm; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_user_user_permissions
    ADD CONSTRAINT content_library_user_permission_id_93c7b786_fk_auth_perm FOREIGN KEY (permission_id) REFERENCES public.auth_permission(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_user_groups content_library_user_user_id_5baf34c3_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_user_groups
    ADD CONSTRAINT content_library_user_user_id_5baf34c3_fk_content_l FOREIGN KEY (user_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_library_user_user_permissions content_library_user_user_id_6c771372_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_library_user_user_permissions
    ADD CONSTRAINT content_library_user_user_id_6c771372_fk_content_l FOREIGN KEY (user_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: django_admin_log django_admin_log_content_type_id_c4bce8eb_fk_django_co; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_content_type_id_c4bce8eb_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: django_admin_log django_admin_log_user_id_c564eba6_fk_content_library_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_user_id_c564eba6_fk_content_library_user_id FOREIGN KEY (user_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: django_celery_beat_periodictask django_celery_beat_p_clocked_id_47a69f82_fk_django_ce; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_celery_beat_periodictask
    ADD CONSTRAINT django_celery_beat_p_clocked_id_47a69f82_fk_django_ce FOREIGN KEY (clocked_id) REFERENCES public.django_celery_beat_clockedschedule(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: django_celery_beat_periodictask django_celery_beat_p_crontab_id_d3cba168_fk_django_ce; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_celery_beat_periodictask
    ADD CONSTRAINT django_celery_beat_p_crontab_id_d3cba168_fk_django_ce FOREIGN KEY (crontab_id) REFERENCES public.django_celery_beat_crontabschedule(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: django_celery_beat_periodictask django_celery_beat_p_interval_id_a8ca27da_fk_django_ce; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_celery_beat_periodictask
    ADD CONSTRAINT django_celery_beat_p_interval_id_a8ca27da_fk_django_ce FOREIGN KEY (interval_id) REFERENCES public.django_celery_beat_intervalschedule(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: django_celery_beat_periodictask django_celery_beat_p_solar_id_a87ce72c_fk_django_ce; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_celery_beat_periodictask
    ADD CONSTRAINT django_celery_beat_p_solar_id_a87ce72c_fk_django_ce FOREIGN KEY (solar_id) REFERENCES public.django_celery_beat_solarschedule(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: oauth2_provider_accesstoken oauth2_provider_acce_application_id_b22886e1_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth2_provider_accesstoken
    ADD CONSTRAINT oauth2_provider_acce_application_id_b22886e1_fk_content_l FOREIGN KEY (application_id) REFERENCES public.content_library_application(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: oauth2_provider_accesstoken oauth2_provider_acce_user_id_6e4c9a65_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth2_provider_accesstoken
    ADD CONSTRAINT oauth2_provider_acce_user_id_6e4c9a65_fk_content_l FOREIGN KEY (user_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: oauth2_provider_grant oauth2_provider_gran_application_id_81923564_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth2_provider_grant
    ADD CONSTRAINT oauth2_provider_gran_application_id_81923564_fk_content_l FOREIGN KEY (application_id) REFERENCES public.content_library_application(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: oauth2_provider_grant oauth2_provider_gran_user_id_e8f62af8_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth2_provider_grant
    ADD CONSTRAINT oauth2_provider_gran_user_id_e8f62af8_fk_content_l FOREIGN KEY (user_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: oauth2_provider_refreshtoken oauth2_provider_refr_application_id_2d1c311b_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth2_provider_refreshtoken
    ADD CONSTRAINT oauth2_provider_refr_application_id_2d1c311b_fk_content_l FOREIGN KEY (application_id) REFERENCES public.content_library_application(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: oauth2_provider_refreshtoken oauth2_provider_refr_user_id_da837fce_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth2_provider_refreshtoken
    ADD CONSTRAINT oauth2_provider_refr_user_id_da837fce_fk_content_l FOREIGN KEY (user_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: oauth2_provider_refreshtoken oauth2_provider_refreshtoken_access_token_id_775e84e8_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth2_provider_refreshtoken
    ADD CONSTRAINT oauth2_provider_refreshtoken_access_token_id_775e84e8_fk FOREIGN KEY (access_token_id) REFERENCES public.oauth2_provider_accesstoken(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: organizations_organizationuser organizations_organi_organization_id_5376c939_fk_organizat; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations_organizationuser
    ADD CONSTRAINT organizations_organi_organization_id_5376c939_fk_organizat FOREIGN KEY (organization_id) REFERENCES public.organizations_organization(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: organizations_organizationowner organizations_organi_organization_id_7e98f9c0_fk_organizat; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations_organizationowner
    ADD CONSTRAINT organizations_organi_organization_id_7e98f9c0_fk_organizat FOREIGN KEY (organization_id) REFERENCES public.organizations_organization(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: organizations_organizationowner organizations_organi_organization_user_id_c9c76850_fk_organizat; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations_organizationowner
    ADD CONSTRAINT organizations_organi_organization_user_id_c9c76850_fk_organizat FOREIGN KEY (organization_user_id) REFERENCES public.organizations_organizationuser(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: organizations_organizationuser organizations_organi_user_id_6c888ebd_fk_content_l; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations_organizationuser
    ADD CONSTRAINT organizations_organi_user_id_6c888ebd_fk_content_l FOREIGN KEY (user_id) REFERENCES public.content_library_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- PostgreSQL database dump complete
--

