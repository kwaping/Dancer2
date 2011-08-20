use strict;
use warnings;
use Test::More;

use Dancer::Core::App;
use Dancer::Core::Route;
use Dancer::Core::Dispatcher;
use Dancer::Core::Hook;

# init our test fixture
my $buffer = {};
my $app = Dancer::Core::App->new(name => 'main');

# a simple / route
$app->add_route(
    method => 'get',
    regexp => '/',
    code => sub { "home" },
);

# A chain of two route for /user/$foo 
$app->add_route(
    method => 'get',
    regexp => '/user/:name',
    code => sub {
        my $ctx = shift;
        $buffer->{user} = $ctx->request->params->{'name'};
        $ctx->response->{has_passed} = 1;
    },
);

$app->add_route(
    method => 'get',
    regexp => '/user/*?',
    code => sub {
        my $ctx = shift;
        "Hello " . $ctx->request->params->{'name'};
    },
);

# the tests
my @tests = (
    {   env => {
            REQUEST_METHOD => 'GET',
            PATH_INFO      => '/',
        },
        expected => [200, [], ["home"]]
    },
    {   env => {
            REQUEST_METHOD => 'GET',
            PATH_INFO      => '/user/Johnny',
        },
        expected => [200, [], ["Hello Johnny"]]
    },
    {   env => {
            REQUEST_METHOD => 'POST',
            PATH_INFO      => '/user/Johnny',
        },
        expected => [404, [], ["404 Not Found\n\n/user/Johnny\n"]]
    },
# NOT SUPPORTED YET
#    {   env => {
#            REQUEST_METHOD => 'GET',
#            PATH_INFO      => '/admin',
#        },
#        expected => [200, [], ["home"]]
#    },


);

# before hook that produces a manual forward
$app->add_hook(Dancer::Core::Hook->new(
    name => 'before', 
    code => sub {
        my $ctx = shift;
        if ($ctx->request->path_info eq '/admin') {
            $ctx->request->path_info('/');
        }
    },
));

plan tests => scalar(@tests);

my $dispatcher = Dancer::Core::Dispatcher->new(apps => [$app]);
foreach my $test (@tests) {
    my $env = $test->{env};
    my $expected = $test->{expected};

    my $resp = $dispatcher->dispatch($env);
    is_deeply $resp, $expected;
}
