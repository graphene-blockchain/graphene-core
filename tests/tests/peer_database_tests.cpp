/*
 * Copyright (c) 2026 carbon-witness, and contributors.
 *
 * The MIT License
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#include <graphene/net/peer_database.hpp>
#include <graphene/utilities/tempdir.hpp>

#include <boost/test/unit_test.hpp>

using namespace graphene::net;

BOOST_AUTO_TEST_SUITE(peer_database_tests)

/**
 * The P2P node closes its peer database more than once on shutdown. Every close after the
 * first one must leave the saved file alone instead of overwriting it with an empty list.
 */
BOOST_AUTO_TEST_CASE( repeated_close_keeps_saved_peers )
{
   fc::temp_directory td( graphene::utilities::temp_directory_path() );
   const fc::path db_file = td.path() / "p2p" / "peers.json";
   const fc::ip::endpoint peer = fc::ip::endpoint::from_string( "127.0.0.1:1776" );

   peer_database db;
   db.open( db_file );
   db.update_entry( db.lookup_or_create_entry_for_endpoint( peer ) );
   db.close();
   db.close();

   peer_database reopened;
   reopened.open( db_file );
   BOOST_CHECK_EQUAL( reopened.size(), 1u );
   BOOST_CHECK( reopened.lookup_entry_for_endpoint( peer ).valid() );
   reopened.close();
}

BOOST_AUTO_TEST_SUITE_END()
