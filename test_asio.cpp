#include <asio.hpp>
int main() {
    asio::io_context service;
    asio::ip::tcp::resolver resolver(service);
    asio::ip::tcp::resolver::query query("localhost", "80");
    resolver.async_resolve(query, [](const std::error_code& error, auto results) {
        typedef decltype(results) ResType;
        static_assert(std::is_same_v<ResType, asio::ip::tcp::resolver::results_type>, "not results_type");
        static_assert(std::is_same_v<ResType, asio::ip::tcp::resolver::results_type::iterator>, "not iterator");
    });
    return 0;
}
