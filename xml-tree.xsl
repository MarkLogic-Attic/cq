<?xml version="1.0" encoding="utf-8"?>
<!--
 -  Copyright (c)2008-2010 Mark Logic Corporation. All Rights Reserved.
 -
 -  Licensed under the Apache License, Version 2.0 (the "License");
 -  you may not use this file except in compliance with the License.
 -  You may obtain a copy of the License at
 -
 -  http//www.apache.org/licenses/LICENSE-2.0
 -
 -  Unless required by applicable law or agreed to in writing, software
 -  distributed under the License is distributed on an "AS IS" BASIS,
 -  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 -  See the License for the specific language governing permissions and
 -  limitations under the License.
 -
 -  The use of the Apache License does not indicate that this project is
 -  affiliated with the Apache Software Foundation.
 -->
<!-- xslt-2 would be nice, but browsers do not support it yet -->
<xsl:stylesheet version="1.0"
                xmlns="http://www.w3.org/1999/xhtml"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output
      method="xml"
      doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"
      doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN"
      />

  <!-- comments -->
  <xsl:template match="comment()">
    <xc>&lt;-- <xsl:value-of select="."/> --&gt;</xc>
  </xsl:template>

  <!-- attributes -->
  <xsl:template match="@*">
    <xa><xsl:text> </xsl:text><xsl:value-of
    select="name()"/><xav><xsl:value-of select="."/></xav></xa>
  </xsl:template>

  <xsl:template match="processing-instruction()">
    <!-- omit any PI for this xsl -->
    <xsl:if test="name(.) != 'xml-stylesheet'
                  or not(contains(., 'href=&quot;xml-tree.xsl'))">
    <xpi>&lt;?<xsl:value-of
    select="name()"/><xsl:text> </xsl:text><xsl:value-of
    select="."/>?&gt;</xpi>
    </xsl:if>
  </xsl:template>

  <xsl:template match="text()"><xsl:copy-of select="."/></xsl:template>

  <xsl:template match="*">
    <!-- start tag, attribute nodes, and namespaces -->
    <xe>&lt;<xsl:value-of
    select="name()"/><xsl:apply-templates
    select="@*"/><xsl:variable name="ns"
    select="namespace::*"/><xsl:variable name="pns"
    select="../namespace::*"/><xsl:if test="$ns"><xsl:for-each
    select="$ns[not(. = $pns)]"><xsl:variable name="prefix"
    select="local-name(.)"/> xmlns<xsl:if test="$prefix">:<xsl:value-of
    select="$prefix"/></xsl:if>="<xsl:value-of
    select="string()"/>"</xsl:for-each></xsl:if></xe><xsl:variable
    name="node-count"
    select="count(node())"/>
    <xsl:choose>
      <!-- empty? -->
      <xsl:when test="0 = $node-count">/&gt;</xsl:when>
      <xsl:otherwise>
        <xe>/&gt;</xe>
        <xsl:variable name="text-count" select="count(text())"/>
        <!-- any text child nodes? -->
        <xsl:choose>
          <!-- if found, add tree widget, intially expanded -->
          <xsl:when test="$node-count != $text-count">
            <xw>—</xw>
            <ul><xsl:for-each select="node()">
              <li><xsl:apply-templates select="."/></li>
            </xsl:for-each></ul>
          </xsl:when>
          <xsl:otherwise><xsl:apply-templates/></xsl:otherwise>
        </xsl:choose>
        <!-- end tag -->
        <xe>&lt;/<xsl:value-of select="name()"/>&gt;</xe>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="/">
    <html>
      <head>
        <title>XML Tree View</title>
        <link rel="stylesheet" type="text/css" href="xml-tree.css"/>
      </head>
      <body>
        <div class="DEBUG"><xsl:value-of
        select="system-property('xsl:version')"/></div>
        <div class="DEBUG"><xsl:value-of select="generate-id(.)"/></div>
        <div id="tree">
          <xsl:for-each select="node()">
            <div><xsl:apply-templates select="."/></div>
          </xsl:for-each>
        </div>
      </body>
    </html>
  </xsl:template>

</xsl:stylesheet>
